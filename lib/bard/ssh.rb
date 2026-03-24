require "uri"
require "bard/ssh_server"
require "bard/command"
require "bard/copy"

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
      result = Command.run!(command, on: self, home: home, verbose: verbose, quiet: quiet)
      result if capture
    end

    def run(command, home: false, verbose: false, quiet: false)
      Command.run(command, on: self, home: home, verbose: verbose, quiet: quiet)
    end

    def exec!(command, home: false)
      Command.exec!(command, on: self, home: home)
    end

    def copy_file(path, to:, verbose: false)
      Copy.file(path, from: self, to: to, verbose: verbose)
    end

    def copy_dir(path, to:, verbose: false)
      Copy.dir(path, from: self, to: to, verbose: verbose)
    end
  end
end
