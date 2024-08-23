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

    def scp_using_local direction, server
      gateway = server.gateway ? "-oProxyCommand='ssh #{server.ssh_uri(:gateway)} -W %h:%p'" : ""

      ssh_key = server.ssh_key ? "-i #{server.ssh_key}" : ""

      from_and_to = [path, server.scp_uri(path)]
      from_and_to.reverse! if direction == :from

      command = ["scp", gateway, ssh_key, *from_and_to].join(" ")
      Bard::Command.run! command, verbose: verbose
    end

    def scp_as_mediator
      raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key
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

    def rsync_using_local direction, server
      gateway = server.gateway ? "-oProxyCommand=\"ssh #{server.ssh_uri(:gateway)} -W %h:%p\"" : ""

      ssh_key = server.ssh_key ? "-i #{server.ssh_key}" : ""
      ssh = "-e'ssh #{gateway} -p#{server.ssh_uri.port || 22}'"

      from_and_to = ["./#{path}", server.rsync_uri(path)]
      from_and_to.reverse! if direction == :from
      from_and_to[-1].sub! %r(/[^/]+$), '/'

      command = "rsync #{ssh} --delete --info=progress2 -az #{from_and_to.join(" ")}"
      Bard::Command.run! command, verbose: verbose
    end

    def rsync_as_mediator
      raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key

      from_str = "-p#{from.ssh_uri.port || 22} #{from.ssh_uri.user}@#{from.ssh_uri.host}"
      to_str = to.rsync_uri(path).sub(%r(/[^/]+$), '/')

      command = %(ssh -A #{from_str} 'rsync -e \"ssh -A -p#{to.ssh_uri.port || 22} -o StrictHostKeyChecking=no\" --delete --info=progress2 -az #{from.path}/#{path} #{to_str}')
      Bard::Command.run! command, verbose: verbose
    end
  end
end
