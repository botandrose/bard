require "bard/target"
require "bard/default_config"

module Bard
  class Config
    attr_reader :project_name, :targets

    def initialize(project_name = nil, path: nil, source: nil)
      # Support both positional and keyword argument for project_name
      @project_name = project_name
      @targets = {}
      @data_paths = []
      @backup = nil
      @ci_system = nil

      # Load default configuration first
      DEFAULT_CONFIG.call(self, project_name) if project_name

      # Load user configuration
      if path && File.exist?(path)
        source = File.read(path)
      end
      if source
        instance_eval(source)
      end
    end

    # DSL method for defining targets
    def target(key, &block)
      key = key.to_sym
      @targets[key] ||= Target.new(key, self)
      @targets[key].instance_eval(&block) if block
      @targets[key]
    end

    # Alias for backward compatibility (will be deprecated in v1.9.x)
    alias_method :server, :target

    # Also expose @targets as @servers for compatibility
    def servers
      @targets
    end

    # Get a target by key
    def [](key)
      key = key.to_sym
      # Fallback to staging if production not defined
      if @targets[key].nil? && key == :production
        key = :staging
      end
      @targets[key]
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

      target :production do
        github_pages url
        ssh false
        ping(*urls) if urls.any?
      end

      backup false
    end
  end
end
