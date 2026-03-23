require "bard/plugin"

class Bard::CLI::Hurt < Bard::Plugin::Command
  desc "hurt <command>", "reruns a command until it fails"
  def hurt *args
    (1..).each do |count|
      puts "Running attempt #{count}"
      system *args
      unless $?.success?
        puts "Ran #{count-1} times before failing"
        break
      end
    end
  end
end

