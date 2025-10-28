require "open3"
require "bard/ci/state"

module Bard
  class CI
    class Local < Struct.new(:project_name, :branch, :sha)
      def run
        start
        @start_time = Time.new.to_i
        save_state

        while building?
          elapsed_time = Time.new.to_i - @start_time
          yield elapsed_time, nil
          save_state
          sleep(2)
        end

        @stdin.close
        @console = @stdout_and_stderr.read
        @stdout_and_stderr.close

        state.delete
        success?
      end

      def exists?
        true
      end

      def console
        @console
      end

      def resume
        saved_state = state.load
        raise "No saved CI state found for #{project_name}. Start a new build with 'bard ci'." if saved_state.nil?

        raise "Cannot resume local CI: process is no longer running. Start a new build with 'bard ci'."
      end

      def save_state
        state.save({
          "project_name" => project_name,
          "branch" => branch,
          "start_time" => @start_time
        })
      end

      def state
        @state ||= State.new(project_name)
      end

      private

      def start
        @stdin, @stdout_and_stderr, @wait_thread = Open3.popen2e("CLEAN=true bin/rake ci")
      end

      def building?
        ![nil, false].include?(@wait_thread.status)
      end

      def success?
        @wait_thread.value.success?
      end
    end
  end
end

