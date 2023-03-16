require "thor"
require "time"
require "json"
require "net/http"

class Bard::CLI < Thor
  class CI
    class GithubActions < Struct.new(:project_name, :branch, :sha)
      def run
        api = API.new(project_name)
        last_time_elapsed = api.last_successful_run.time_elapsed
        @run = api.create_run!(branch)

        start_time = Time.new.to_i
        while @run.building?
          elapsed_time = Time.new.to_i - start_time
          yield elapsed_time, last_time_elapsed
          sleep(2)
          @run = api.find_run(@run.id)
        end

        @run.success?
      end

      def exists?
        true
      end

      def console
        @run.console
      end

      def last_response
      end

      class API < Struct.new(:project_name)
        def last_successful_run
          successful_runs = client.get("runs", status: "success", per_page: 1)
          json = successful_runs["workflow_runs"][0]
          Run.new(self, json)
        end

        def find_run id
          json = client.get("runs/#{id}")
          Run.new(self, json)
        end

        def create_run! branch
          start_time = Time.now
          client.post("workflows/ci.yml/dispatches", ref: branch, inputs: { "git-ref": branch })
          sha = `git rev-parse #{branch}`.chomp

          loop do
            runs = client.get("runs", head_sha: sha, created: ">#{start_time.iso8601}")
            if json = runs["workflow_runs"].first
              return Run.new(self, json)
            end
            sleep 1
          end
        end

        def find_job_by_run_id run_id
          jobs = client.get("runs/#{run_id}/jobs", filter: "latest", per_page: 1)
          job_json = jobs["jobs"][0]
          Job.new(self, job_json)
        end

        def download_logs_by_job_id job_id
          client.get("jobs/#{job_id}/logs")
        end

        private

        def client
          @client ||= Client.new(project_name)
        end
      end

      class Run < Struct.new(:api, :json)
        def id
          json["id"]
        end

        def time_elapsed
          job.time_elapsed
        end

        def building?
          %w[in_progress queued requested waiting pending]
            .include?(json["status"])
        end

        def success?
          json["status"] == "completed" && json["conclusion"] == "success"
        end

        def job
          @job ||= api.find_job_by_run_id(id)
        end

        def console
          job.logs
        end
      end

      class Job < Struct.new(:api, :json)
        def id
          json["id"]
        end

        def time_elapsed
          Time.parse(json["completed_at"]).to_i -
            Time.parse(json["started_at"]).to_i
        end

        def logs
          @logs ||= api.download_logs_by_job_id(id)
        end
      end

      class Client < Struct.new(:project_name)
        def get path, params={}
          request(path) do |uri|
            uri.query = URI.encode_www_form(params)
            Net::HTTP::Get.new(uri)
          end
        end

        def post path, params={}
          request(path) do |uri|
            Net::HTTP::Post.new(uri).tap do |r|
              r.body = JSON.dump(params)
            end
          end
        end

        private

        def github_apikey
          @github_apikey ||= begin
            raw = `git ls-remote -t git@github.com:botandrose/bard`
            raw[/github-apikey\|(.+)$/, 1]
          end
        end

        def request path, &block
          uri = if path =~ /^http/
            URI(path)
          else
            URI("https://api.github.com/repos/botandrosedesign/#{project_name}/actions/#{path}")
          end

          response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
            request = block.call(uri)
            request["Accept"] = "application/vnd.github+json"
            request["Authorization"] = "Token #{github_apikey}"
            request["X-GitHub-Api-Version"] = "2022-11-28"
            http.request(request)
          end

          case response
          when Net::HTTPRedirection then
            url = response["Location"]
            request(url) do |uri|
              Net::HTTP::Get.new(uri)
            end
          when Net::HTTPSuccess then
            if response["Content-Type"].to_s.include?("/json")
              JSON.load(response.body)
            else
              response.body
            end
          else
            raise response.inspect
          end
        end
      end
    end
  end
end

