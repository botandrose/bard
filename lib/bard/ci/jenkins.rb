require "json"
require "bard/ci/state"
require "bard/ci/retryable"

module Bard
  class CI
    class Jenkins < Struct.new(:project_name, :branch, :sha)
      include Retryable

      def run
        @last_time_elapsed = get_last_time_elapsed
        start
        @start_time = Time.new.to_i
        save_state
        sleep(2) until started?

        while building?
          elapsed_time = Time.new.to_i - @start_time
          yield elapsed_time, @last_time_elapsed
          save_state
          sleep(2)
        end

        state.delete
        success?
      end

      def exists?
        `curl -s -I #{ci_host}/` =~ /\b200 OK\b/
      end

      def console
        raw = `curl -s #{ci_host}/lastBuild/console`
        raw[%r{<pre.*?>(.+)</pre>}m, 1]
      end

      def resume
        saved_state = state.load
        raise "No saved CI state found for #{project_name}. Start a new build with 'bard ci'." if saved_state.nil?

        @queueId = saved_state["queue_id"]
        @job_id = saved_state["job_id"]

        start_time = saved_state["start_time"]
        last_time_elapsed = saved_state["last_time_elapsed"]

        while building?
          elapsed_time = Time.new.to_i - start_time
          yield elapsed_time, last_time_elapsed
          save_state
          sleep(2)
        end

        state.delete
        success?
      end

      attr_accessor :last_response

      private

      def get_last_time_elapsed
        retry_with_backoff do
          response = `curl -s #{ci_host}/lastStableBuild/api/xml`
          raise "Blank response from CI" if response.blank?
          response
        end
        response.match(/<duration>(\d+)<\/duration>/)
        $1 ? $1.to_i / 1000 : nil
      rescue => e
        puts "  Warning: Could not get last build duration: #{e.message}"
        nil
      end

      def auth
        "botandrose:11cc2ba6ef2e43fbfbedc1f466724f6290"
      end

      def ci_host
        "http://#{auth}@ci.botandrose.com/job/#{project_name}"
      end

      def start
        command = "curl -s -I -X POST -L '#{ci_host}/buildWithParameters?GIT_REF=#{sha}'"
        output = `#{command}`
        @queueId = output[%r{Location: .+/queue/item/(\d+)/}, 1].to_i
      end

      def started?
        retry_with_backoff do
          command = "curl -s -g '#{ci_host}/api/json?depth=1&tree=builds[queueId,number]'"
          output = `#{command}`
          raise "Blank response from CI" if output.blank?
          JSON.parse(output)["builds"][0]["queueId"] == @queueId
        end
      end

      def job_id
        @job_id ||= begin
          retry_with_backoff do
            output = `curl -s -g '#{ci_host}/api/json?depth=1&tree=builds[queueId,number]'`
            raise "Blank response from CI" if output.blank?
            output[/"number":(\d+),"queueId":#{@queueId}\b/, 1].to_i
          end
        end
      end

      def building?
        retry_with_backoff do
          self.last_response = `curl -s #{ci_host}/#{job_id}/api/json?tree=building,result`
          raise "Blank response from CI" if last_response.blank?
        end
        last_response.include? '"building":true'
      end

      def success?
        last_response.include? '"result":"SUCCESS"'
      end

      def save_state
        state.save({
          "project_name" => project_name,
          "branch" => branch,
          "queue_id" => @queueId,
          "job_id" => @job_id,
          "start_time" => @start_time,
          "last_time_elapsed" => @last_time_elapsed
        })
      end

      def state
        @state ||= State.new(project_name)
      end
    end
  end
end

