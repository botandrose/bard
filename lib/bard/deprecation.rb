module Bard
  module Deprecation
    @warned = {}

    def self.warn(message, callsite: nil)
      callsite ||= caller_locations(2, 1).first
      key = "#{callsite.path}:#{callsite.lineno}:#{message}"
      return if @warned[key]

      @warned[key] = true
      location = "#{callsite.path}:#{callsite.lineno}"
      Kernel.warn "[DEPRECATION] #{message} (called from #{location})"
    end

    def self.reset!
      @warned = {}
    end
  end
end
