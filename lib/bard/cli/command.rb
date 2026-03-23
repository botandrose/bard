require "delegate"

class Bard::CLI::Command < SimpleDelegator
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
