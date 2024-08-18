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
      uri = URI.parse("ssh://#{server.gateway}")
      port = uri.port ? "-p#{uri.port}" : ""
      gateway = server.gateway ? "-oProxyCommand='ssh #{port} #{uri.user}@#{uri.host} -W %h:%p'" : ""

      ssh_key = server.ssh_key ? "-i #{server.ssh_key}" : ""

      uri = URI.parse("ssh://#{server.ssh}")
      port = uri.port ? "-P#{uri.port}" : ""
      from_and_to = [path, "#{uri.user}@#{uri.host}:#{server.path}/#{path}"]

      from_and_to.reverse! if direction == :from
      command = "scp #{gateway} #{ssh_key} #{port} #{from_and_to.join(" ")}"

      Bard::Command.run! command, verbose: verbose
    end

    def scp_as_mediator
      raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key

      from_uri = URI.parse("ssh://#{from.ssh}")
      from_str = "scp://#{from_uri.user}@#{from_uri.host}:#{from_uri.port || 22}/#{from.path}/#{path}"

      to_uri = URI.parse("ssh://#{to.ssh}")
      to_str = "scp://#{to_uri.user}@#{to_uri.host}:#{to_uri.port || 22}/#{to.path}/#{path}"

      command = "scp -o ForwardAgent=yes #{from_str} #{to_str}"

      Bard::Command.run! command, verbose: verbose
    end

    def rsync
      if from.key == :local
        rsync_using_local :to, to
      elsif to.key == :local
        rsync_using_local :from, from
      else
        rsync_as_mediator from, to
      end
    end

    def rsync_using_local direction, server
      uri = URI.parse("ssh://#{server.gateway}")
      port = uri.port ? "-p#{uri.port}" : ""
      gateway = server.gateway ? "-oProxyCommand=\"ssh #{port} #{uri.user}@#{uri.host} -W %h:%p\"" : ""

      ssh_key = server.ssh_key ? "-i #{server.ssh_key}" : ""
      uri = URI.parse("ssh://#{server.ssh}")
      port = uri.port ? "-p#{uri.port}" : ""
      ssh = "-e'ssh #{ssh_key} #{port} #{gateway}'"

      dest_path = path.dup
      dest_path = "./#{dest_path}"
      from_and_to = [dest_path, "#{uri.user}@#{uri.host}:#{server.path}/#{path}"]
      from_and_to.reverse! if direction == :from
      from_and_to[-1].sub! %r(/[^/]+$), '/'

      command = "rsync #{ssh} --delete --info=progress2 -az #{from_and_to.join(" ")}"

      Bard::Command.run! command, verbose: verbose
    end

    def rsync_as_mediator from, to
      raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key

      dest_path = path.dup
      dest_path = "./#{dest_path}"

      from_uri = URI.parse("ssh://#{from.ssh}")
      from_str = "-p#{from_uri.port || 22} #{from_uri.user}@#{from_uri.host}"

      to_uri = URI.parse("ssh://#{to.ssh}")
      to_str = "#{to_uri.user}@#{to_uri.host}:#{to.path}/#{path}"
      to_str.sub! %r(/[^/]+$), '/'

      command = %(ssh -A #{from_str} 'rsync -e \"ssh -A -p#{to_uri.port || 22} -o StrictHostKeyChecking=no\" --delete --info=progress2 -az #{from.path}/#{path} #{to_str}')

      Bard::Command.run! command, verbose: verbose
    end
  end
end
