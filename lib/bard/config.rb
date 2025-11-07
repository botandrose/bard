require "bard/server"
require "bard/target"

module Bard
  class Config
    attr_reader :project_name

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

    # Backup configuration
    def backup(value = nil)
      if value.nil?
        return @backup if @backup != nil
        @backup = true  # Default to true
      else
        @backup = value
      end
    end

    def backup_enabled?
      backup == true
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

      # Use the existing CI class which handles auto-detection
      case @ci_system
      when :local
        CI.new(project_name, branch, local: true)
      when :github_actions, :jenkins, nil
        # CI class auto-detects between github_actions and jenkins
        CI.new(project_name, branch)
      when false
        nil
      else
        CI.new(project_name, branch)
      end
    end

    # Shorthand for GitHub Pages (compatibility method)
    def github_pages(url = nil)
      urls = []
      if url && url.length > 0
        uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
        hostname = uri.hostname.sub(/^www\./, '')
        urls = [hostname]
        if hostname.count(".") < 2
          urls << "www.#{hostname}"
        end
      end

      server :production do
        github_pages true
        ssh false
        ping(*urls) if urls.any?
      end

      backup false
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
end
