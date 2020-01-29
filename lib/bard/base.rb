require "thor"
require "term/ansicolor"
require "open3"

class Bard::CLI < Thor
  include Term::ANSIColor

  private

  def run_crucial(command, verbose = false)
    stdout, stderr, status = Open3.capture3(command)
    failed = status.to_i.nonzero?
    if verbose || failed
      $stdout.puts stdout
      $stderr.puts stderr
    end
    if failed
      puts red("!!! ") + "Running command failed: #{yellow(command)}"
      exit 1
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
    dest_path = "./#{dest_path}"
    from_and_to = [dest_path, "#{uri.user}@#{uri.host}:#{server.path}/#{path}"]
    from_and_to.reverse! if direction == :from
    from_and_to[-1].sub! %r(/[^/]+$), '/'

    command = "rsync #{ssh} --delete -avz #{from_and_to.join(" ")}"

    run_crucial command
  end
end

