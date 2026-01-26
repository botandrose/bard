require "bard/server"
require "bard/target"
require "bard/deprecation"

module Bard
  class Config
    def self.current(working_directory: Dir.getwd)
      project_name = File.basename(working_directory)
      path = File.join(working_directory, "bard.rb")
      new(project_name, path: path)
    end

    attr_reader :project_name, :targets

    def initialize(project_name = nil, path: nil, source: nil)
      # Support both positional and keyword argument for project_name
      @project_name = project_name
      @servers = {}  # Unified hash for both Server and Target instances
      @data_paths = []
      @backup = nil
      @ci_system = nil

      # Load default configuration (creates Server instances for backward compat)
      load_defaults if project_name

      # Load user configuration
      if path && File.exist?(path)
        source = File.read(path)
      end
      if source
        instance_eval(source)
      end
    end

    # Backward compatible accessor
    def servers
      @servers
    end

    # New v2.0 accessor (same as servers)
    def targets
      @servers
    end

    # Old v1.x API - creates Server instances
    def server(key, &block)
      Deprecation.warn "`server` is deprecated; use `target` instead (will be removed in v2.0)"
      key = key.to_sym
      @servers[key] = Server.define(project_name, key, &block)
    end

    # New v2.0 API - creates Target instances
    def target(key, &block)
      key = key.to_sym
      @servers[key] ||= Target.new(key, self)
      @servers[key].instance_eval(&block) if block
      @servers[key]
    end

    # Get a server/target by key
    def [](key)
      key = key.to_sym
      # Fallback to staging if production not defined
      if @servers[key].nil? && key == :production
        key = :staging
      end
      @servers[key]
    end

    # Data paths configuration
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

    # CI configuration
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

    # Load default server configurations (v1.x compatible)
    def load_defaults
      @servers[:local] = Server.new(
        project_name,
        :local,
        false,
        "./",
        ["#{project_name}.local"],
      )
      @servers[:gubs] = Server.new(
        project_name,
        :gubs,
        "botandrose@cloud.hackett.world:22022",
        "Sites/#{project_name}",
        false,
      )
      @servers[:ci] = Server.new(
        project_name,
        :ci,
        "jenkins@staging.botandrose.com:22022",
        "jobs/#{project_name}/workspace",
        false,
      )
      @servers[:staging] = Server.new(
        project_name,
        :staging,
        "www@staging.botandrose.com:22022",
        project_name,
        ["#{project_name}.botandrose.com"],
      )
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
