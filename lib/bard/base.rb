require "thor"
require "term/ansicolor"
require "open3"
require "uri"

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

  def ssh_command server, command, home: false
    server = @config.servers[server.to_sym]
    uri = URI.parse("ssh://#{server.ssh}")
    ssh_key = server.ssh_key ? "-i #{server.ssh_key} " : ""
    command = "#{server.env} #{command}" if server.env
    command = "cd #{server.path} && #{command}" unless home
    command = "ssh -tt #{ssh_key}#{"-p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} '#{command}'"
    if server.gateway
      uri = URI.parse("ssh://#{server.gateway}")
      command = "ssh -tt #{" -p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} \"#{command}\""
    end
    command
  end

  def copy direction, server, path, verbose: false
    server = @config.servers[server.to_sym]

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

  def rsync direction, server, path, verbose: false
    server = @config.servers[server.to_sym]

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
end

