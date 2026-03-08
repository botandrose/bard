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
      @backup = nil
      @ci_system = nil

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

    def backup(value = nil, &block)
      if block_given?
        @backup = BackupConfig.new(&block)
      elsif value == false
        @backup = BackupConfig.new { disabled }
      elsif value.nil? # Getter
        @backup ||= BackupConfig.new { bard }
      else
        raise ArgumentError, "backup accepts false or a block"
      end
    end

    def backup_enabled?
      backup == true
    end

    def github_pages url
      urls = []
      uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
      hostname = uri.hostname.sub(/^www\./, '')
      urls = [hostname]
      if hostname.count(".") < 2
        urls << "www.#{hostname}"
      end

      target :production do
        github_pages url
        ssh false
        ping(*urls) if urls.any?
      end

      backup false
    end

    def ci(system = nil)
      if system.nil?
        @ci_system
      else
        @ci_system = system
      end
    end

    def ci_system
      @ci_system
    end

    def ci_instance(branch)
      return nil if @ci_system == false

      require "bard/ci"
      CI.new(project_name, branch, runner_name: @ci_system)
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

  class BackupConfig
    attr_reader :destinations

    def initialize(&block)
      @destinations = []
      instance_eval(&block) if block_given?
    end

    def bard
      @bard = true
    end

    def bard?
      !!@bard
    end

    def disabled
      @disabled = true
    end

    def disabled?
      !!@disabled
    end

    def enabled?
      !disabled?
    end

    def s3(name, **kwargs)
      @destinations << {
        name: name,
        type: :s3,
        **kwargs,
      }
    end

    def self_managed?
      @destinations.any?
    end
  end
end
