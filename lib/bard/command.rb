require "open3"

module Bard
  module Command
    class Error < RuntimeError; end

    def self.run!(command, verbose: false, quiet: false)
      result = run(command, verbose:, quiet:)
      raise Error.new(command) unless result
      result
    end

    def self.run(command, verbose: false, quiet: false)
      if verbose
        system command
      else
        stdout, stderr, status = Open3.capture3(command)
        failed = status.to_i.nonzero?
        if failed && !quiet
          $stdout.puts stdout
          $stderr.puts stderr
        end
        !failed && stdout
      end
    end

    def self.exec!(command)
      Kernel.exec command
    end
  end
end
