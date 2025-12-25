require "uri"
require "bard/command"
require "bard/copy"
require "bard/deploy_strategy"
require "bard/deprecation"

module Bard
  class Target
    attr_reader :key, :config
    attr_accessor :server

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

        # Auto-configure ping from hostname
        hostname = @server.hostname
        ping("https://#{hostname}") if hostname
      end
    end

    def ssh_uri
      server&.ssh_uri
    end

    # Path configuration
    def path(new_path = nil)
      if new_path
        Deprecation.warn "Separate `path` call is deprecated; pass as keyword argument to `ssh` instead, e.g., `ssh \"user@host\", path: \"#{new_path}\"` (will be removed in v2.0)"
        @path = new_path
      else
        @path || config.project_name
      end
    end

    # Deprecated separate setter methods - use ssh(..., option: value) instead
    def gateway(value = nil)
      if value
        Deprecation.warn "Separate `gateway` call is deprecated; pass as keyword argument to `ssh` instead, e.g., `ssh \"user@host\", gateway: \"#{value}\"` (will be removed in v2.0)"
        @gateway = value
      else
        @gateway
      end
    end

    def ssh_key(value = nil)
      if value
        Deprecation.warn "Separate `ssh_key` call is deprecated; pass as keyword argument to `ssh` instead, e.g., `ssh \"user@host\", ssh_key: \"#{value}\"` (will be removed in v2.0)"
        @ssh_key = value
      else
        @ssh_key
      end
    end

    def env(value = nil)
      if value
        Deprecation.warn "Separate `env` call is deprecated; pass as keyword argument to `ssh` instead, e.g., `ssh \"user@host\", env: \"#{value}\"` (will be removed in v2.0)"
        @env = value
      else
        @env
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

    # GitHub Pages deployment configuration
    def github_pages(url = nil)
      if url.nil?
        # Getter
        @github_pages_url
      else
        # Setter
        @deploy_strategy = :github_pages
        @github_pages_url = url
        enable_capability(:github_pages)
      end
    end

    # Deprecated strategy configuration methods
    def strategy(name)
      Deprecation.warn "`strategy` is deprecated; use the strategy method directly, e.g., `#{name} \"url\"` instead of `strategy :#{name}` (will be removed in v2.0)"
      @deploy_strategy = name
    end

    def option(key, value)
      Deprecation.warn "`option` is deprecated; pass options as keyword arguments to the strategy method, e.g., `jets \"url\", #{key}: #{value.inspect}` (will be removed in v2.0)"
      @strategy_options_hash[@deploy_strategy] ||= {}
      @strategy_options_hash[@deploy_strategy][key] = value
    end

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
      Command.run!(command, on: self, home: home, verbose: verbose, quiet: quiet)
    end

    def run(command, home: false, verbose: false, quiet: false)
      require_capability!(:ssh)
      Command.run(command, on: self, home: home, verbose: verbose, quiet: quiet)
    end

    def exec!(command, home: false)
      require_capability!(:ssh)
      Command.exec!(command, on: self, home: home)
    end

    # File transfer
    def copy_file(path, to:, verbose: false)
      require_capability!(:ssh)
      to.require_capability!(:ssh) if to.respond_to?(:require_capability!)
      Copy.file(path, from: self, to: to, verbose: verbose)
    end

    def copy_dir(path, to:, verbose: false)
      require_capability!(:ssh)
      to.require_capability!(:ssh) if to.respond_to?(:require_capability!)
      Copy.dir(path, from: self, to: to, verbose: verbose)
    end

    # URI methods for compatibility
    def scp_uri(file_path = nil)
      # Use traditional scp format: user@host:path (relative to home)
      # Port is NOT included here - it must be passed via -P flag to scp
      full_path = path
      full_path += "/#{file_path}" if file_path
      "#{server.user}@#{server.host}:#{full_path}"
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
