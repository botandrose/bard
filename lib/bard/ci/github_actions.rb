require "time"
require "bard/github"
require "bard/ci/runner"

module Bard
  class CI
    class GithubActions < Runner
      def exists?
        File.exist?(".github/workflows/ci.yml")
      end

      def console
        @run.console
      end

      def status
        last_run = api.last_run
        if last_run.building?
          "Building..."
        elsif last_run.success?
          "Succeeded!"
        elsif last_run.failure?
          "Failed!\n\n#{last_run.console}"
        else
          raise "Unknown job status: #{last_run.inspect}"
        end
      end

      protected

      def start
        @run = api.create_run!(branch)
      end

      def get_last_time_elapsed
        api.last_successful_run&.time_elapsed
      end

      def building?
        @run.building?
      end

      def success?
        @run.success?
      end

      def get_state_data
        {
          "project_name" => project_name,
          "branch" => branch,
          "run_id" => @run.id,
          "start_time" => @start_time,
          "last_time_elapsed" => @last_time_elapsed
        }
      end

      def restore_state(data)
        @run = api.find_run(data["run_id"])
        @start_time = data["start_time"]
        @last_time_elapsed = data["last_time_elapsed"]
      end

      def poll_until_complete
        while @run.building?
          elapsed_time = Time.new.to_i - @start_time
          yield elapsed_time, @last_time_elapsed
          save_state
          sleep(2)
          @run = api.find_run(@run.id)
        end
      end

      private

      def api
        @api ||= API.new(project_name)
      end

      class API < Struct.new(:project_name)
        def last_run
          response = client.get("actions/runs", event: "workflow_dispatch", per_page: 1)
          if json = response["workflow_runs"][0]
            Run.new(self, json)
          end
        end

        def last_successful_run
          successful_runs = client.get("actions/runs", event: "workflow_dispatch", status: "success", per_page: 1)
          if json = successful_runs["workflow_runs"][0]
            Run.new(self, json)
          end
        end

        def find_run id
          json = client.get("actions/runs/#{id}")
          Run.new(self, json)
        end

        def create_run! branch
          start_time = Time.now
          client.post("actions/workflows/ci.yml/dispatches", ref: branch, inputs: { "git-ref": branch })
          sha = `git rev-parse #{branch}`.chomp

          loop do
            runs = client.get("actions/runs", event: "workflow_dispatch", head_sha: sha, created: ">#{start_time.iso8601}")
            if json = runs["workflow_runs"].first
              return Run.new(self, json)
            end
            sleep 1
          end
        end

        def find_job_by_run_id run_id
          jobs = client.get("actions/runs/#{run_id}/jobs", filter: "latest", per_page: 1)
          job_json = jobs["jobs"][0]
          Job.new(self, job_json)
        end

        def download_logs_by_job_id job_id
          client.get("actions/jobs/#{job_id}/logs")
        end

        private

        def client
          @client ||= Bard::Github.new(project_name)
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
          status == "completed" && conclusion == "success"
        end

        def failure?
          conclusion == "failure"
        end

        def job
          @job ||= api.find_job_by_run_id(id)
        end

        def console
          job.logs
        end

        def branch
          json["head_branch"]
        end

        def sha
          json["head_sha"]
        end

        def status
          json["status"]
        end

        def conclusion
          json["conclusion"]
        end

        def started_at
          Time.parse(json["run_started_at"])
        end

        def updated_at
          Time.parse(json["updated_at"])
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
    end
  end
end

