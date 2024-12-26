require "open3"

module Bard
  class Command < Struct.new(:command, :on, :home)
    class Error < RuntimeError; end

    def self.run! command, on: :local, home: false, verbose: false, quiet: false
      new(command, on, home).run! verbose:, quiet:
    end

    def self.run command, on: :local, home: false, verbose: false, quiet: false
      new(command, on, home).run verbose:, quiet:
    end

    def self.exec! command, on: :local, home: false
      new(command, on, home).exec!
    end

    def run! verbose: false, quiet: false
      if !run(verbose:, quiet:)
        raise Error.new(full_command)
      end
    end

    def run verbose: false, quiet: false
      # no-op if server doesn't really exist
      return true if on.respond_to?(:ssh) && on.ssh == false

      if verbose
        system full_command(quiet: quiet)
      else
        stdout, stderr, status = Open3.capture3(full_command)
        failed = status.to_i.nonzero?
        if failed && !quiet
          $stdout.puts stdout
          $stderr.puts stderr
        end
        !failed && stdout
      end
    end

    def exec!
      exec full_command
    end

    private

    def full_command quiet: false
      if on.to_sym == :local
        command
      else
        remote_command quiet: false
      end
    end

    def remote_command quiet: false
      cmd = command
      if on.env
        cmd = "#{on.env} #{command}"
      end
      unless home
        cmd = "cd #{on.path} && #{cmd}"
      end
      ssh_key = on.ssh_key ? "-i #{on.ssh_key} " : ""
      cmd = "ssh -tt #{ssh_key} #{on.ssh_uri} '#{cmd}'"
      if on.gateway
        cmd = "ssh -tt #{on.ssh_uri(:gateway)} \"#{cmd}\""
      end
      cmd += " 2>&1" if quiet
      cmd
    end
  end
end
