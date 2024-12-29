require "delegate"

class Bard::CLI::Command < SimpleDelegator
  def self.desc command, description
    @command = command
    @method = command.split(" ").first.to_sym
    @description = description
  end

  def self.setup cli
    cli.desc @command, @description

    method = @method # put in local variable so next block can capture it
    cli.define_method method do |*args|
      command = Bard::CLI::New.new(self)
      command.send method, *args
    end
  end
end
