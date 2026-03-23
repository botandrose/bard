require "uri"
require "bard/command"
require "bard/copy"
require "bard/deploy_strategy"

module Bard
  class Target
    attr_reader :key, :config
    attr_accessor :server

    def initialize(key, config)
      @key = key
      @config = config
      @capabilities = []
      @url = nil
      @strategy_options_hash = {}
      @deploy_strategy = nil
      @path = nil
      @server = nil
    end

    # Capability tracking
    def enable_capability(capability)
      @capabilities << capability unless @capabilities.include?(capability)
    end

    def has_capability?(capability)
      @capabilities.include?(capability)
    end

    def require_capability!(capability)
      unless has_capability?(capability)
        error_message = case capability
        when :ssh
          "SSH not configured for this target"
        when :url
          "URL not configured for this target"
        else
          "#{capability} capability not configured for this target"
        end
        raise error_message
      end
    end

    # SSH configuration
    def ssh(uri_or_false = nil, **options)
      if uri_or_false.nil?
        # Getter - return false if explicitly disabled, otherwise return server
        return @ssh_disabled ? false : @server
      elsif uri_or_false == false
        # Disable SSH
        @server = nil
        @ssh_disabled = true
        @capabilities.delete(:ssh)
      else
        # Enable SSH
        require "bard/ssh_server"
        @server = SSHServer.new(uri_or_false, **options)
        @path = options[:path] if options[:path]
        @gateway = options[:gateway] if options[:gateway]
        @ssh_key = options[:ssh_key] if options[:ssh_key]
        @env = options[:env] if options[:env]
        enable_capability(:ssh)

        # Set SSH as default deployment strategy if none set
        @deploy_strategy ||= :ssh

        # Auto-configure url from hostname
        hostname = @server.hostname
        url("https://#{hostname}") if hostname
      end
    end

    def ssh_uri
      server&.ssh_uri
    end

    # Attribute readers
    def path
      @path || config.project_name
    end

    attr_reader :gateway, :ssh_key, :env

    # URL configuration
    def url(value = nil)
      if value.nil?
        @url
      elsif value == false
        @url = nil
        @capabilities.delete(:url)
      else
        @url = normalize_url(value)
        enable_capability(:url)
      end
    end

    # Deploy strategy
    attr_reader :deploy_strategy

    def strategy_options(strategy_name)
      @strategy_options_hash[strategy_name] || {}
    end

    def deploy_strategy_instance
      raise "No deployment strategy configured for target #{key}" unless @deploy_strategy

      strategy_class = DeployStrategy[@deploy_strategy]
      raise "Unknown deployment strategy: #{@deploy_strategy}" unless strategy_class

      strategy_class.new(self)
    end

    # Dynamic strategy DSL via method_missing
    def method_missing(method, *args, **kwargs, &block)
      strategy_class = DeployStrategy[method]

      if strategy_class
        # This is a deployment strategy
        @deploy_strategy = method

        # Store options
        @strategy_options_hash[method] = kwargs

        # Auto-configure url if first arg is a URL
        if args.first && args.first.to_s =~ /^https?:\/\//
          url(args.first)
        end
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      DeployStrategy[method] || super
    end

    # Remote command execution
    def run!(command, home: false, verbose: false, quiet: false, capture: false)
      require_capability!(:ssh) unless key == :local
      result = Command.run!(command, on: self, home: home, verbose: verbose, quiet: quiet)
      result if capture
    end

    def run(command, home: false, verbose: false, quiet: false)
      require_capability!(:ssh) unless key == :local
      Command.run(command, on: self, home: home, verbose: verbose, quiet: quiet)
    end

    def exec!(command, home: false)
      require_capability!(:ssh) unless key == :local
      Command.exec!(command, on: self, home: home)
    end

    # File transfer
    def copy_file(path, to:, verbose: false)
      require_capability!(:ssh) unless key == :local
      to.require_capability!(:ssh) unless to.key == :local
      Copy.file(path, from: self, to: to, verbose: verbose)
    end

    def copy_dir(path, to:, verbose: false)
      require_capability!(:ssh) unless key == :local
      to.require_capability!(:ssh) unless to.key == :local
      Copy.dir(path, from: self, to: to, verbose: verbose)
    end

    # URI methods
    def scp_uri(file_path = nil)
      full_path = "/#{path}"
      full_path += "/#{file_path}" if file_path
      URI::Generic.build(scheme: "scp", userinfo: server.user, host: server.host, port: server.port.to_i, path: full_path)
    end

    def rsync_uri(file_path = nil)
      uri = ssh_uri
      str = "#{uri.user}@#{uri.host}"
      str += ":#{path}"
      str += "/#{file_path}" if file_path
      str
    end

    # Utility methods
    def to_s
      key.to_s
    end

    def to_sym
      key
    end

    def with(attrs)
      dup.tap do |t|
        attrs.each do |key, value|
          t.send(key, value)
        end
      end
    end

    private

    def normalize_url(value)
      normalized = value.to_s
      normalized = "https://#{normalized}" unless normalized.start_with?("http")
      normalized
    end
  end
end
