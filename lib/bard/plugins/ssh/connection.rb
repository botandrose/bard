require "uri"
require "bard/plugins/ssh/server"

# Data-only SSH mixin: enough for the parser to hold a target's connection details and
# derive its url. The command-running methods (run!/ssh_command) live in bard-cli.
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
  end
end
