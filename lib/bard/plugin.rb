module Bard
  module Plugin
    class Command
      def self.inherited(subclass)
        super
        Bard::Plugin.commands << subclass
      end

      def self.desc(command, description)
        @command = command
        @method = command.split(" ").first.to_sym
        @description = description
      end

      def self.option(*args, **kwargs)
        @options ||= []
        @options << [args, kwargs]
      end

      def self.setup(cli)
        cli.desc @command, @description
        (@options || []).each do |args, kwargs|
          cli.option(*args, **kwargs)
        end
        command_class = self
        method = @method
        cli.define_method(method) do |*args|
          command_class.new(self).send(method, *args)
        end
      end

      # Kernel methods resolve on the object itself, bypassing method_missing.
      # Explicitly delegate them so command output goes through the CLI context.
      [:puts, :print, :exit, :system, :exec, :`].each do |m|
        define_method(m) { |*args, &block| @cli.__send__(m, *args, &block) }
      end

      def initialize(cli)
        @cli = cli
      end

      private

      def method_missing(method, *args, **kwargs, &block)
        if @cli.respond_to?(method, true)
          @cli.send(method, *args, **kwargs, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        @cli.respond_to?(method, include_private) || super
      end
    end

    @commands = []

    class << self
      attr_reader :commands

      def load!(cli = nil)
        load_builtins
        load_externals
        commands.each { |cmd| cmd.setup(cli) }
      end

      def reset!
        @commands = []
      end

      private

      def load_builtins
        Dir[File.join(__dir__, "plugins", "*.rb")].sort.each { |f| require f }
      end

      def load_externals
        Dir[File.join(Dir.pwd, "lib", "bard", "plugins", "*.rb")].sort.each { |f| require f }
      end
    end
  end
end
