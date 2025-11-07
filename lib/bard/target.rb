require "uri"
require "bard/command"
require "bard/copy"
require "bard/deploy_strategy"

module Bard
  class Target
    attr_reader :key, :config, :path
    attr_accessor :server, :gateway, :ssh_key, :env

    def initialize(key, config)
      @key = key
      @config = config
      @capabilities = []
      @ping_urls = []
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
        when :ping
          "Ping URL not configured for this target"
        else
          "#{capability} capability not configured for this target"
        end
        raise error_message
      end
    end

    # SSH configuration
    def ssh(uri_or_false = nil, **options)
      if uri_or_false.nil?
        # Getter
        return @server
      elsif uri_or_false == false
        # Disable SSH
        @server = nil
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

        # Auto-configure ping from hostname
        hostname = @server.hostname
        ping(hostname) if hostname
      end
    end

    def ssh_uri
      server&.ssh_uri
    end

    # Path configuration
    def path(new_path = nil)
      if new_path
        @path = new_path
      else
        @path || config.project_name
      end
    end

    # Ping configuration
    def ping(*urls)
      if urls.empty?
        # Getter
        @ping_urls
      elsif urls.first == false
        # Disable ping
        @ping_urls = []
        @capabilities.delete(:ping)
      else
        # Enable ping
        @ping_urls = urls.flatten
        enable_capability(:ping)
      end
    end

    def ping_urls
      @ping_urls
    end

    def ping!
      require_capability!(:ping)
      require "bard/ping"
      failed_urls = Bard::Ping.call(self)
      if failed_urls.any?
        raise "Ping failed for: #{failed_urls.join(', ')}"
      end
    end

    def open
      require_capability!(:ping)
      system "open #{ping_urls.first}"
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

        # Auto-configure ping if first arg is a URL
        if args.first && args.first.to_s =~ /^https?:\/\//
          ping(args.first)
        end

        # Call the strategy's initializer if it wants to configure the target
        # (This will be handled by the strategy class)
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      DeployStrategy[method] || super
    end

    # Remote command execution
    def run!(command, home: false, verbose: false, quiet: false)
      require_capability!(:ssh)
      Command.run!(command, on: server, home: home, verbose: verbose, quiet: quiet)
    end

    def run(command, home: false, verbose: false, quiet: false)
      require_capability!(:ssh)
      Command.run(command, on: server, home: home, verbose: verbose, quiet: quiet)
    end

    def exec!(command, home: false)
      require_capability!(:ssh)
      Command.exec!(command, on: server, home: home)
    end

    # File transfer
    def copy_file(path, to:, verbose: false)
      require_capability!(:ssh)
      to.require_capability!(:ssh)
      Copy.file(path, from: self, to: to, verbose: verbose)
    end

    def copy_dir(path, to:, verbose: false)
      require_capability!(:ssh)
      to.require_capability!(:ssh)
      Copy.dir(path, from: self, to: to, verbose: verbose)
    end

    # URI methods for compatibility
    def scp_uri(file_path = nil)
      uri = URI("scp://#{ssh_uri}")
      uri.path = "/#{path}"
      uri.path += "/#{file_path}" if file_path
      uri
    end

    def rsync_uri(file_path = nil)
      uri = URI("ssh://#{ssh_uri}")
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
  end
end
