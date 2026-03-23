require "bard/target"

module Bard
  class Config
    def self.current(working_directory: Dir.getwd)
      project_name = File.basename(working_directory)
      path = File.join(working_directory, "bard.rb")
      new(project_name, path: path)
    end

    attr_reader :project_name, :targets

    def initialize(project_name = nil, path: nil, source: nil)
      @project_name = project_name
      @targets = {}
      @data_paths = []

      load_defaults if project_name

      if path && File.exist?(path)
        source = File.read(path)
      end
      if source
        instance_eval(source)
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

    def data(*paths)
      if paths.empty?
        @data_paths
      else
        @data_paths = paths
      end
    end

    def data_paths
      @data_paths
    end

    private

    def load_defaults
      target :local do
        ssh false
        ping false
      end

      target :gubs do
        ssh "botandrose@cloud.hackett.world:22022"
        ping false
      end

      target :ci do
        ssh "jenkins@staging.botandrose.com:22022",
          path: "jobs/#{config.project_name}/workspace"
        ping false
      end

      target :staging do
        ssh "www@staging.botandrose.com:22022"
        ping "#{config.project_name}.botandrose.com"
      end
    end
  end

end
