require "uri"
require "bard/command"

module Bard
  class Copy < Struct.new(:path, :from, :to, :verbose)
    def self.file path, from:, to:, verbose: false
      new(path, from, to, verbose).scp
    end

    def self.dir path, from:, to:, verbose: false
      new(path, from, to, verbose).rsync
    end

    def scp
      if from.key == :local
        scp_using_local :to, to
      elsif to.key == :local
        scp_using_local :from, from
      else
        scp_as_mediator
      end
    end

    def scp_using_local direction, target_or_server
      # Support both new Target (with server attribute) and old Server
      ssh_server = target_or_server.respond_to?(:server) ? target_or_server.server : target_or_server

      gateway = ssh_server.gateway ? "-oProxyCommand='ssh #{ssh_server.gateway} -W %h:%p'" : ""

      ssh_key = ssh_server.ssh_key ? "-i #{ssh_server.ssh_key}" : ""

      from_and_to = [path, target_or_server.scp_uri(path)]
      from_and_to.reverse! if direction == :from

      command = ["scp", gateway, ssh_key, *from_and_to].join(" ")
      Bard::Command.run! command, verbose: verbose
    end

    def scp_as_mediator
      from_server = from.respond_to?(:server) ? from.server : from
      to_server = to.respond_to?(:server) ? to.server : to

      raise NotImplementedError if from_server.gateway || to_server.gateway || from_server.ssh_key || to_server.ssh_key
      command = "scp -o ForwardAgent=yes #{from.scp_uri(path)} #{to.scp_uri(path)}"
      Bard::Command.run! command, verbose: verbose
    end

    def rsync
      if from.key == :local
        rsync_using_local :to, to
      elsif to.key == :local
        rsync_using_local :from, from
      else
        rsync_as_mediator
      end
    end

    def rsync_using_local direction, target_or_server
      # Support both new Target (with server attribute) and old Server
      ssh_server = target_or_server.respond_to?(:server) ? target_or_server.server : target_or_server

      # Get ssh_uri - it might be a URI object (old Server), string (new SSHServer), or mock
      ssh_uri_value = ssh_server.respond_to?(:ssh_uri) ? ssh_server.ssh_uri : nil
      if ssh_uri_value.respond_to?(:port)
        # Already a URI-like object (old Server or mock)
        ssh_uri = ssh_uri_value
      elsif ssh_uri_value.is_a?(String)
        # String from new SSHServer
        ssh_uri = URI("ssh://#{ssh_uri_value}")
      else
        # Fallback
        ssh_uri = ssh_uri_value
      end

      gateway = ssh_server.gateway ? "-oProxyCommand=\"ssh #{ssh_server.gateway} -W %h:%p\"" : ""

      ssh_key = ssh_server.ssh_key ? "-i #{ssh_server.ssh_key}" : ""
      ssh = "-e'ssh #{gateway} -p#{ssh_uri.port || 22}'"

      from_and_to = ["./#{path}", target_or_server.rsync_uri(path)]
      from_and_to.reverse! if direction == :from
      from_and_to[-1].sub! %r(/[^/]+$), '/'

      command = "rsync #{ssh} --delete --info=progress2 -az #{from_and_to.join(" ")}"
      Bard::Command.run! command, verbose: verbose
    end

    def rsync_as_mediator
      from_server = from.respond_to?(:server) ? from.server : from
      to_server = to.respond_to?(:server) ? to.server : to

      raise NotImplementedError if from_server.gateway || to_server.gateway || from_server.ssh_key || to_server.ssh_key

      # Get ssh_uri - it might be a URI object (old Server), string (new SSHServer), or mock
      from_uri_value = from_server.respond_to?(:ssh_uri) ? from_server.ssh_uri : nil
      if from_uri_value.respond_to?(:port)
        from_uri = from_uri_value
      elsif from_uri_value.is_a?(String)
        from_uri = URI("ssh://#{from_uri_value}")
      else
        from_uri = from_uri_value
      end

      to_uri_value = to_server.respond_to?(:ssh_uri) ? to_server.ssh_uri : nil
      if to_uri_value.respond_to?(:port)
        to_uri = to_uri_value
      elsif to_uri_value.is_a?(String)
        to_uri = URI("ssh://#{to_uri_value}")
      else
        to_uri = to_uri_value
      end

      from_str = "-p#{from_uri.port || 22} #{from_uri.user}@#{from_uri.host}"
      to_str = to.rsync_uri(path).sub(%r(/[^/]+$), '/')

      command = %(ssh -A #{from_str} 'rsync -e \"ssh -A -p#{to_uri.port || 22} -o StrictHostKeyChecking=no\" --delete --info=progress2 -az #{from.path}/#{path} #{to_str}')
      Bard::Command.run! command, verbose: verbose
    end
  end
end
