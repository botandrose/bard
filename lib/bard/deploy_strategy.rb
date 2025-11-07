require "bard/command"

module Bard
  class DeployStrategy
    @strategies = {}

    class << self
      attr_reader :strategies

      def inherited(subclass)
        super
        # Extract strategy name from class name
        # e.g., Bard::DeployStrategy::SSH -> :ssh
        name = extract_strategy_name(subclass)
        strategies[name] = subclass
      end

      def [](name)
        strategies[name.to_sym]
      end

      private

      def extract_strategy_name(klass)
        # Get the class name without module prefix
        class_name = klass.name.split('::').last
        # Convert from CamelCase to snake_case
        class_name
          .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
          .gsub(/([a-z\d])([A-Z])/, '\1_\2')
          .downcase
          .to_sym
      end
    end

    attr_reader :target

    def initialize(target)
      @target = target
    end

    def deploy
      raise NotImplementedError, "Subclasses must implement #deploy"
    end

    # Helper methods for strategies
    def run!(command)
      Command.run!(command)
    end

    def run(command)
      Command.run(command)
    end

    def system!(command)
      result = Kernel.system(command)
      raise "Command failed: #{command}" unless result
    end
  end
end
