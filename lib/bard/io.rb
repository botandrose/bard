module BardIO
  include Term::ANSIColor
  private

    def warn(message)
      message = message.message if message.is_a? BardError
      $stderr.puts yellow("!   ") + message
    end

    def fatal(message)
      raise red("!!! ") + message
    end

    def run_crucial(command, verbose = false)
      status, stdout, stderr = systemu command
      fatal "Running command: #{yellow(command)}: #{stderr}" if status.to_i.nonzero?
      if verbose
        $stdout.puts stdout
        $stderr.puts stderr
      end
      stdout.chomp
    end

    def project_name
      @project_name ||= File.expand_path(".").split("/").last
    end
end
