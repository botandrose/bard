require "open3"

module Bard
  class CI
    class Local < Struct.new(:project_name, :branch, :sha)
      def run
        start

        start_time = Time.new.to_i
        while building?
          elapsed_time = Time.new.to_i - start_time
          yield elapsed_time, nil
          sleep(2)
        end

        @stdin.close
        @console = @stdout_and_stderr.read
        @stdout_and_stderr.close

        success?
      end

      def exists?
        true
      end

      def console
        @console
      end

      attr_accessor :last_response

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

