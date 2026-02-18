module Bard
  class Plugin
    @registry = {}

    class << self
      attr_reader :registry

      def register(name, &block)
        plugin = new(name)
        plugin.instance_eval(&block) if block
        @registry[name.to_sym] = plugin
      end

      def [](name)
        @registry[name.to_sym]
      end

      def all
        @registry.values
      end

      def load_all!
        Dir[File.join(__dir__, "plugins", "*.rb")].sort.each { |f| require f }
        Dir[File.join(Dir.pwd, "lib", "bard", "plugins", "*.rb")].sort.each { |f| require f }
        all.each(&:apply!)
      end

      def reset!
        @registry = {}
      end
    end

    attr_reader :name, :cli_modules

    def initialize(name)
      @name = name.to_sym
      @cli_modules = []
      @cli_requires = []
      @target_methods = {}
      @config_methods = {}
      @requires = []
    end

    # DSL methods for defining plugins

    def require_file(path)
      @requires << path
    end

    def cli(mod, require: nil)
      @cli_requires << require if require
      @cli_modules << mod
    end

    def target_method(name, &block)
      @target_methods[name] = block
    end

    def config_method(name, &block)
      @config_methods[name] = block
    end

    # Apply plugin to the system (non-CLI parts)
    def apply!
      @requires.each { |path| require path }
      apply_target_methods!
      apply_config_methods!
    end

    def apply_to_cli(cli_class)
      @cli_requires.each { |path| require path }
      @cli_modules.each do |mod|
        mod = resolve_constant(mod) if mod.is_a?(String)
        mod.setup(cli_class)
      end
    end

    private

    def apply_target_methods!
      return if @target_methods.empty?
      require "bard/target"
      @target_methods.each do |method_name, block|
        Target.define_method(method_name, &block)
      end
    end

    def apply_config_methods!
      return if @config_methods.empty?
      require "bard/config"
      @config_methods.each do |method_name, block|
        Config.define_method(method_name, &block)
      end
    end

    def resolve_constant(name)
      name.split("::").reduce(Object) { |mod, const| mod.const_get(const) }
    end
  end
end
