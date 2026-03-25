require "uri"
require "bard/command"

module Bard
  class Target
    attr_reader :key, :config

    def initialize(key, config)
      @key = key
      @config = config
      @capabilities = []
      @url = nil
      @path = nil
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
        raise "#{capability} capability not configured for this target"
      end
    end

    def path
      @path || config.project_name
    end

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

    def run!(command, home: false, verbose: false, quiet: false, capture: false)
      result = Command.run!(command, home: home, verbose: verbose, quiet: quiet)
      result if capture
    end

    def run(command, home: false, verbose: false, quiet: false)
      Command.run(command, home: home, verbose: verbose, quiet: quiet)
    end

    def exec!(command, home: false)
      Command.exec!(command, home: home)
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
