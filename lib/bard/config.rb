require "bard/target"
require "bard/plugins/ssh/target_methods"

module Bard
  class Config
    def self.current
      new(detect_project_name, path: "bard.rb")
    end

    def self.detect_project_name
      git_common_dir = `git rev-parse --git-common-dir 2>/dev/null`.chomp
      dirname = if $?.success? && !git_common_dir.empty?
        File.dirname(File.expand_path(git_common_dir))
      else
        Dir.getwd
      end
      File.basename(dirname)
    end

    attr_reader :project_name, :targets

    def initialize(project_name = nil, path: nil, source: nil)
      @project_name = project_name
      @targets = {}
      load_defaults if project_name

      if path && File.exist?(path)
        source = File.read(path)
      end
      if source
        instance_eval(source, path)
      end
    end

    def remove_target(key)
      @targets.delete(key.to_sym)
    end

    def target(key, &block)
      key = key.to_sym
      unless @targets[key].is_a?(Target)
        @targets[key] = Target.new(key, self)
      end
      @targets[key].instance_eval(&block) if block
      @targets[key]
    end

    def [](key)
      key = key.to_sym
      if @targets[key].nil? && key == :production
        key = :staging
      end
      @targets[key]
    end

    private

    def load_defaults
      target :local

      target :gubs do
        ssh "botandrose@cloud.hackett.world:22022",
          path: "Sites/#{config.project_name}"
        url false
      end

      target :ci do
        ssh "jenkins@staging.botandrose.com:22022",
          path: "jobs/#{config.project_name}/workspace"
        url false
      end

      target :staging do
        ssh "www@staging.botandrose.com:22022"
        url "#{config.project_name}.botandrose.com"
      end
    end
  end
end
