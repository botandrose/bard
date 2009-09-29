module BardIO
  include Term::ANSIColor
  private

    def warn(message)
      $stderr.puts yellow("!!! ") + message
    end

    def fatal(message)
      raise Thor::Error, red("!!! ") + message
    end

    def run_crucial(command)
      status, stdout, stderr = systemu command
      fatal "Running command: #{yellow(command)}: #{stderr}" if status.to_i.nonzero?
      stdout.chomp
    end
end
