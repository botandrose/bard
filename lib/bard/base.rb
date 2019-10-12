require "thor"
require "term/ansicolor"
require "systemu"

class Bard::CLI < Thor
  include Term::ANSIColor

  private

  def fatal(message)
    raise red("!!! ") + message
  end

  def run_crucial(command, verbose = false)
    status, stdout, stderr = systemu command
    fatal "Running command: #{yellow(command)}: #{stderr}" if status.to_i.nonzero?
    if verbose
      $stdout.puts stdout
      $stderr.puts stderr
    end
    stdout.chomp
  end

  def project_name
    @project_name ||= File.expand_path(".").split("/").last
  end

  def ssh_command server, command, home: false
    server = @config.servers[server.to_sym]
    uri = URI.parse("ssh://#{server.ssh}")
    command = "cd #{server.path} && #{command}" unless home
    command = "ssh -tt #{"-p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} '#{command}'"
    if server.gateway
      uri = URI.parse("ssh://#{server.gateway}")
      command = "ssh -tt #{" -p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} \"#{command}\""
    end
    command
  end

  def copy direction, server, path
    server = @config.servers[server.to_sym]

    uri = URI.parse("ssh://#{server.gateway}")
    port = uri.port ? "-p#{uri.port}" : ""
    gateway = server.gateway ? "-oProxyCommand='ssh #{port} #{uri.user}@#{uri.host} -W %h:%p'" : ""

    uri = URI.parse("ssh://#{server.ssh}")
    port = uri.port ? "-P#{uri.port}" : ""
    from_and_to = [path, "#{uri.user}@#{uri.host}:#{server.path}/#{path}"]

    from_and_to.reverse! if direction == :from
    command = "scp #{gateway} #{port} #{from_and_to.join(" ")}"

    run_crucial command
  end

  def rsync direction, server, path
    server = @config.servers[server.to_sym]

    uri = URI.parse("ssh://#{server.gateway}")
    port = uri.port ? "-p#{uri.port}" : ""
    gateway = server.gateway ? "-oProxyCommand=\"ssh #{port} #{uri.user}@#{uri.host} -W %h:%p\"" : ""

    uri = URI.parse("ssh://#{server.ssh}")
    port = uri.port ? "-p#{uri.port}" : ""
    ssh = "-e'ssh #{port} #{gateway}'"

    dest_path = path.dup
    dest_path.sub! %r(/[^/]+$), '/'
    from_and_to = [dest_path, "#{uri.user}@#{uri.host}:#{project_name}/#{path}"]

    from_and_to.reverse! if direction == :from
    command = "rsync #{ssh} --delete -avz #{from_and_to.join(" ")}"

    run_crucial command
  end
end

