require "json"
require "fileutils"

module Bard
  class CI
    class State
      def initialize project_name
        @project_name = project_name
      end

      def save data
        FileUtils.mkdir_p(state_dir)
        File.write(state_file, JSON.generate(data))
      end

      def load
        return nil unless File.exist?(state_file)
        JSON.parse(File.read(state_file))
      end

      def delete
        File.delete(state_file) if File.exist?(state_file)
      end

      def exists?
        File.exist?(state_file)
      end

      private

      def state_dir
        File.join(Dir.pwd, "tmp", "bard", "ci")
      end

      def state_file
        File.join(state_dir, "#{@project_name}.json")
      end
    end
  end
end
