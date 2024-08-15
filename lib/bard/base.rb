require "thor"
require "term/ansicolor"
require "open3"
require "uri"
require "bard/remote_command"

class Bard::CLI < Thor
  include Term::ANSIColor

  private

  def run_crucial command, verbose: false
    failed = false

    if verbose
      failed = !(system command)
    else
      stdout, stderr, status = Open3.capture3(command)
      failed = status.to_i.nonzero?
      if failed
        $stdout.puts stdout
        $stderr.puts stderr
      end
    end

    if failed
      puts red("!!! ") + "Running command failed: #{yellow(command)}"
      exit 1
    end
  end

  def project_name
    @project_name ||= File.expand_path(".").split("/").last
  end

  def ssh_command server_name, command, home: false
    server = @config.servers.fetch(server_name.to_sym)
    Bard::RemoteCommand.new(server, command, home).local_command
  end

  def copy direction, server_name, path, verbose: false
    server = @config.servers.fetch(server_name.to_sym)

    uri = URI.parse("ssh://#{server.gateway}")
    port = uri.port ? "-p#{uri.port}" : ""
    gateway = server.gateway ? "-oProxyCommand='ssh #{port} #{uri.user}@#{uri.host} -W %h:%p'" : ""

    ssh_key = server.ssh_key ? "-i #{server.ssh_key}" : ""

    uri = URI.parse("ssh://#{server.ssh}")
    port = uri.port ? "-P#{uri.port}" : ""
    from_and_to = [path, "#{uri.user}@#{uri.host}:#{server.path}/#{path}"]

    from_and_to.reverse! if direction == :from
    command = "scp #{gateway} #{ssh_key} #{port} #{from_and_to.join(" ")}"

    run_crucial command, verbose: verbose
  end

  def move from_name, to_name, path, verbose: false
    from = @config.servers.fecth(from_name.to_sym)
    to = @config.servers.fetch(to_name.to_sym)
    raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key

    from_uri = URI.parse("ssh://#{from.ssh}")
    from_str = "scp://#{from_uri.user}@#{from_uri.host}:#{from_uri.port || 22}/#{from.path}/#{path}"

    to_uri = URI.parse("ssh://#{to.ssh}")
    to_str = "scp://#{to_uri.user}@#{to_uri.host}:#{to_uri.port || 22}/#{to.path}/#{path}"

    command = "scp -o ForwardAgent=yes #{from_str} #{to_str}"

    run_crucial command, verbose: verbose
  end

  def rsync direction, server_name, path, verbose: false
    server = @config.servers.fetch(server_name.to_sym)

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

    run_crucial command, verbose: verbose
  end

  def rsync_remote from_name, to_name, path, verbose: false
    from = @config.servers.fetch(from_name.to_sym)
    to = @config.servers.fetch(to_name.to_sym)
    raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key

    dest_path = path.dup
    dest_path = "./#{dest_path}"

    from_uri = URI.parse("ssh://#{from.ssh}")
    from_str = "-p#{from_uri.port || 22} #{from_uri.user}@#{from_uri.host}"

    to_uri = URI.parse("ssh://#{to.ssh}")
    to_str = "#{to_uri.user}@#{to_uri.host}:#{to.path}/#{path}"
    to_str.sub! %r(/[^/]+$), '/'

    command = %(ssh -A #{from_str} 'rsync -e \"ssh -A -p#{to_uri.port || 22} -o StrictHostKeyChecking=no\" --delete --info=progress2 -az #{from.path}/#{path} #{to_str}')

    run_crucial command, verbose: verbose
  end
end

