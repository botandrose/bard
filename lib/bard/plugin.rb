require "delegate"

module Bard
  class Plugin
    class Command < SimpleDelegator
      # SimpleDelegator doesn't delegate methods defined on Kernel.
      # Override so Commands behave as if running in the CLI context.
      [:puts, :print, :exit, :system, :exec, :`].each do |m|
        define_method(m) { |*args, &block| __getobj__.__send__(m, *args, &block) }
      end

      def self.desc command, description
        @command = command
        @method = command.split(" ").first.to_sym
        @description = description
      end

      def self.option *args, **kwargs
        @options ||= []
        @options << [args, kwargs]
      end

      def self.setup cli
        cli.desc @command, @description
        (@options || []).each do |args, kwargs|
          cli.option *args, **kwargs
        end
        # put in local variables so next block can capture it
        command_class = self
        method = @method
        cli.define_method method do |*args|
          command = command_class.new(self)
          command.send method, *args
        end
      end
    end

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

      def load!(cli)
        load_builtins
        load_externals
        all.each do |plugin|
          plugin.apply!(cli)
        end
      end

      def reset!
        @registry = {}
      end

      private

      def load_builtins
        Dir[File.join(__dir__, "plugins", "*.rb")].sort.each { |f| require f }
      end

      def load_externals
        Dir[File.join(Dir.pwd, "lib", "bard", "plugins", "*.rb")].sort.each { |f| require f }
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

    def apply!(cli)
      @requires.each { |path| require path }
      apply_target_methods!
      apply_config_methods!
      @cli_requires.each { |path| require path }
      @cli_modules.each do |mod|
        mod = resolve_constant(mod) if mod.is_a?(String)
        mod.setup(cli)
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
