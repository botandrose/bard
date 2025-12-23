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
      if on.to_sym != :local
        # Check for new Target architecture
        if on.respond_to?(:server) && on.server.nil?
          return true
        # Check for old Server architecture
        elsif on.respond_to?(:ssh) && on.ssh == false
          return true
        end
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
      # Support both new Target (with server attribute) and old Server architecture
      ssh_server = on.respond_to?(:server) ? on.server : on

      cmd = command
      if ssh_server.env
        cmd = "#{ssh_server.env} #{command}"
      end
      unless home
        path = on.respond_to?(:path) ? on.path : ssh_server.path
        cmd = "cd #{path} && #{cmd}" if path
      end

      ssh_opts = ["-tt", "-o StrictHostKeyChecking=no", "-o UserKnownHostsFile=/dev/null"]
      ssh_opts << "-i #{ssh_server.ssh_key}" if ssh_server.ssh_key

      # Handle new SSHServer vs old Server architecture
      if ssh_server.respond_to?(:host)
        # New SSHServer - has separate host/port/user
        ssh_opts << "-p #{ssh_server.port}" if ssh_server.port && ssh_server.port != "22"
        ssh_opts << "-o ProxyJump=#{ssh_server.gateway}" if ssh_server.gateway
        ssh_target = "#{ssh_server.user}@#{ssh_server.host}"
      else
        # Old Server - uses URI-based ssh_uri
        ssh_target = ssh_server.ssh_uri
        if ssh_server.gateway
          gateway_uri = ssh_server.ssh_uri(:gateway)
          ssh_opts << "-o ProxyJump=#{gateway_uri}"
        end
      end

      cmd = "ssh #{ssh_opts.join(' ')} #{ssh_target} '#{cmd}'"

      cmd += " 2>&1" if quiet
      cmd
    end
  end
end
