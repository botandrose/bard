require "uri"
require "bard/copy"
require "bard/command"

module Bard
  module SSH
    class Copy < Bard::Copy
    def self.can_handle?(from, to)
      from.has_capability?(:ssh) || to.has_capability?(:ssh)
    end

    def file
      if from.key == :local
        scp_using_local :to, to
      elsif to.key == :local
        scp_using_local :from, from
      else
        scp_as_mediator
      end
    end

    def scp_using_local direction, target
      ssh_server = target.server

      gateway = ssh_server.gateway ? "-oProxyCommand='ssh #{ssh_server.gateway} -W %h:%p'" : ""

      ssh_key = ssh_server.ssh_key ? "-i #{ssh_server.ssh_key}" : ""

      ssh_opts = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

      port = ssh_server.port
      port_opt = port && port.to_s != "22" ? "-P #{port}" : ""

      from_and_to = [path, target.scp_uri(path).to_s]
      from_and_to.reverse! if direction == :from

      command = ["scp", ssh_opts, gateway, ssh_key, port_opt, *from_and_to].reject(&:empty?).join(" ")
      Bard::Command.run! command, verbose: verbose
    end

    def scp_as_mediator
      from_server = from.server
      to_server = to.server

      raise NotImplementedError if from_server.gateway || to_server.gateway || from_server.ssh_key || to_server.ssh_key
      command = "scp -o ForwardAgent=yes #{from.scp_uri(path)} #{to.scp_uri(path)}"
      Bard::Command.run! command, verbose: verbose
    end

    def dir
      if from.key == :local
        rsync_using_local :to, to
      elsif to.key == :local
        rsync_using_local :from, from
      else
        rsync_as_mediator
      end
    end

    def rsync_using_local direction, target
      ssh_server = target.server

      ssh_uri = ssh_server.ssh_uri

      gateway = ssh_server.gateway ? "-oProxyCommand=\"ssh #{ssh_server.gateway} -W %h:%p\"" : ""

      ssh_key = ssh_server.ssh_key ? "-i #{ssh_server.ssh_key}" : ""
      ssh = "-e'ssh #{gateway} -p#{ssh_uri.port || 22}'"

      from_and_to = ["./#{path}", target.rsync_uri(path)]
      from_and_to.reverse! if direction == :from
      from_and_to[-1].sub! %r(/[^/]+$), '/'

      command = "rsync #{ssh} --delete --info=progress2 -az #{from_and_to.join(" ")}"
      Bard::Command.run! command, verbose: verbose
    end

    def rsync_as_mediator
      from_server = from.server
      to_server = to.server

      raise NotImplementedError if from_server.gateway || to_server.gateway || from_server.ssh_key || to_server.ssh_key

      from_uri = from_server.ssh_uri
      to_uri = to_server.ssh_uri

      from_str = "-p#{from_uri.port || 22} #{from_uri.user}@#{from_uri.host}"
      to_str = to.rsync_uri(path).sub(%r(/[^/]+$), '/')

      command = %(ssh -A #{from_str} 'rsync -e \"ssh -A -p#{to_uri.port || 22} -o StrictHostKeyChecking=no -o LogLevel=ERROR\" --delete --info=progress2 -az #{from.path}/#{path} #{to_str}')
      Bard::Command.run! command, verbose: verbose
    end
    end
  end
end
