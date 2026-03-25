require "open3"

module Bard
  class Command < Struct.new(:command)
    class Error < RuntimeError; end

    def self.run!(command, verbose: false, quiet: false)
      new(command).run!(verbose:, quiet:)
    end

    def self.run(command, verbose: false, quiet: false)
      new(command).run(verbose:, quiet:)
    end

    def self.exec!(command)
      new(command).exec!
    end

    def run!(verbose: false, quiet: false)
      result = run(verbose:, quiet:)
      raise Error.new(command) unless result
      result
    end

    def run(verbose: false, quiet: false)
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

    def exec!
      exec command
    end
  end
end
