require "delegate"

class Bard::CLI::Command < SimpleDelegator
  def self.desc command, description
    @command = command
    @method = command.split(" ").first.to_sym
    @description = description
  end

  def self.setup cli
    cli.desc @command, @description
    # put in local variables so next block can capture it
    command_class = self
    method = @method
    cli.define_method method do |*args|
      command = command_class.new(self)
      command.send method, *args
    end
  end
end
