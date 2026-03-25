require "uri"
require "shellwords"
require "bard/plugins/ssh/server"
require "bard/command"
require "bard/plugins/ssh/copy"

module Bard
  module SSH
    def server
      @server
    end

    def gateway
      server.gateway
    end

    def ssh_key
      server.ssh_key
    end

    def env
      server.env
    end

    def ssh_uri
      server.ssh_uri
    end

    def scp_uri(file_path = nil)
      full_path = "/#{path}"
      full_path += "/#{file_path}" if file_path
      URI::Generic.build(scheme: "scp", userinfo: server.user, host: server.host, port: server.port.to_i, path: full_path)
    end

    def rsync_uri(file_path = nil)
      uri = ssh_uri
      str = "#{uri.user}@#{uri.host}"
      str += ":#{path}"
      str += "/#{file_path}" if file_path
      str
    end

    def run!(command, home: false, verbose: false, quiet: false, capture: false)
      result = Command.run!(ssh_command(command, home:), verbose:, quiet:)
      result if capture
    end

    def run(command, home: false, verbose: false, quiet: false)
      Command.run(ssh_command(command, home:), verbose:, quiet:)
    end

    def exec!(command, home: false)
      Command.exec!(ssh_command(command, home:))
    end

    def copy_file(path, to:, verbose: false)
      SSH::Copy.file(path, from: self, to: to, verbose: verbose)
    end

    def copy_dir(path, to:, verbose: false)
      SSH::Copy.dir(path, from: self, to: to, verbose: verbose)
    end

    private

    def ssh_command(command, home: false)
      cmd = command
      cmd = "#{env} #{command}" if env

      unless home
        cmd = "cd #{path} && #{cmd}" if path
      end

      ssh_opts = ["-tt", "-o StrictHostKeyChecking=no", "-o UserKnownHostsFile=/dev/null", "-o LogLevel=ERROR"]
      ssh_opts << "-i #{ssh_key}" if ssh_key
      ssh_opts << "-p #{server.port}" if server.port && server.port != "22"
      ssh_opts << "-o ProxyJump=#{gateway}" if gateway

      ssh_target = "#{server.user}@#{server.host}"

      "ssh #{ssh_opts.join(" ")} #{ssh_target} #{Shellwords.shellescape(cmd)}"
    end
  end
end
