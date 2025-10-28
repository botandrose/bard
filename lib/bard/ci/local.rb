require "open3"
require "bard/ci/runner"

module Bard
  class CI
    class Local < Runner

      def exists?
        true
      end

      def console
        @console
      end

      protected

      def start
        @stdin, @stdout_and_stderr, @wait_thread = Open3.popen2e("CLEAN=true bin/rake ci")
      end

      def building?
        ![nil, false].include?(@wait_thread.status)
      end

      def success?
        @wait_thread.value.success?
      end

      def get_state_data
        {
          "project_name" => project_name,
          "branch" => branch,
          "start_time" => @start_time
        }
      end

      def restore_state(data)
        raise "Cannot resume local CI: process is no longer running. Start a new build with 'bard ci'."
      end

      def poll_until_complete
        while building?
          elapsed_time = Time.new.to_i - @start_time
          yield elapsed_time, nil
          save_state
          sleep(2)
        end

        @stdin.close
        @console = @stdout_and_stderr.read
        @stdout_and_stderr.close
      end
    end
  end
end

