require "bard/command"

module Bard
  class Target
    attr_reader :key, :config

    def initialize(key, config)
      @key = key
      @config = config
      @capabilities = []
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

    def run!(command, home: false, verbose: false, quiet: false, capture: false)
      result = Command.run!(command, verbose:, quiet:)
      result if capture
    end

    def run(command, home: false, verbose: false, quiet: false)
      Command.run(command, verbose:, quiet:)
    end

    def exec!(command, home: false)
      Command.exec!(command)
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
