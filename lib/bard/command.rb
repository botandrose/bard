require "open3"
require "shellwords"

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
      result = run(verbose:, quiet:)
      raise Error.new(full_command) unless result
      result
    end

    def run verbose: false, quiet: false
      if on.to_sym != :local && on.server.nil?
        return true
      end
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
      ssh_server = on.server

      cmd = command
      cmd = "#{on.env} #{command}" if on.env

      unless home
        cmd = "cd #{on.path} && #{cmd}" if on.path
      end

      ssh_opts = ["-tt", "-o StrictHostKeyChecking=no", "-o UserKnownHostsFile=/dev/null", "-o LogLevel=ERROR"]
      ssh_opts << "-i #{on.ssh_key}" if on.ssh_key
      ssh_opts << "-p #{ssh_server.port}" if ssh_server.port && ssh_server.port != "22"
      ssh_opts << "-o ProxyJump=#{on.gateway}" if on.gateway

      ssh_target = "#{ssh_server.user}@#{ssh_server.host}"

      cmd = "ssh #{ssh_opts.join(' ')} #{ssh_target} #{Shellwords.shellescape(cmd)}"

      cmd += " 2>&1" if quiet
      cmd
    end
  end
end
