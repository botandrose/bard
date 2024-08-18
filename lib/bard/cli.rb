require "thor"
require "bard/git"
require "bard/ci"
require "bard/data"
require "bard/github"
require "bard/ping"
require "bard/config"
require "bard/remote_command"
require "term/ansicolor"
require "open3"
require "uri"

module Bard
  class CLI < Thor
    include Thor::Actions

    desc "data --from=production --to=local", "copy database and assets from from to to"
    method_options %w[from] => :string, %w[to] => :string
    def data
      default_from = config.servers.key?(:production) ? "production" : "staging"
      from = options.fetch(:from, default_from)
      to = options.fetch(:to, "local")
      Data.new(self, from, to).call
    end

    method_options %w( verbose -v ) => :boolean
    desc "stage [BRANCH=HEAD]", "pushes current branch, and stages it"
    def stage branch=Git.current_branch
      unless config.servers.key?(:production)
        raise Thor::Error.new("`bard stage` is disabled until a production server is defined. Until then, please use `bard deploy` to deploy to the staging server.")
      end

      run_crucial "git push -u origin #{branch}", verbose: true
      command = "git fetch && git checkout -f origin/#{branch} && bin/setup"
      run_crucial ssh_command(:staging, command)
      puts green("Stage Succeeded")

      ping :staging
    end

    method_options %w[verbose -v] => :boolean, %w[skip-ci] => :boolean, %w[local-ci -l] => :boolean
    desc "deploy [TO=production]", "checks that current branch is a ff with master, checks with ci, merges into master, deploys to target, and then deletes branch."
    def deploy to=nil
      branch = Git.current_branch

      if branch == "master"
        run_crucial "git push origin #{branch}:#{branch}" if !Git.up_to_date_with_remote?(branch)
        invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

      else
        run_crucial "git fetch origin master:master"

        unless Git.fast_forward_merge?("origin/master", branch)
          puts "The master branch has advanced. Attempting rebase..."
          run_crucial "git rebase origin/master"
        end

        run_crucial "git push -f origin #{branch}:#{branch}"

        invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

        run_crucial "git push origin #{branch}:master"
        run_crucial "git fetch origin master:master"
      end

      if `git remote` =~ /\bgithub\b/
        run_crucial "git push github"
      end

      to ||= config.servers.key?(:production) ? :production : :staging

      command = "git pull origin master && bin/setup"
      run_crucial ssh_command(to, command)

      puts green("Deploy Succeeded")

      if branch != "master"
        puts "Deleting branch: #{branch}"
        run_crucial "git push --delete origin #{branch}"

        if branch == Git.current_branch
          run_crucial "git checkout master"
        end

        run_crucial "git branch -D #{branch}"
      end

      ping to
    end

    method_options %w[verbose -v] => :boolean, %w[local-ci -l] => :boolean, %w[status -s] => :boolean
    desc "ci [BRANCH=HEAD]", "runs ci against BRANCH"
    def ci branch=Git.current_branch
      ci = CI.new(project_name, branch, local: options["local-ci"])
      if ci.exists?
        return puts ci.status if options["status"]

        puts "Continuous integration: starting build on #{branch}..."

        success = ci.run do |elapsed_time, last_time|
          if last_time
            percentage = (elapsed_time.to_f / last_time.to_f * 100).to_i
            output = "  Estimated completion: #{percentage}%"
          else
            output = "  No estimated completion time. Elapsed time: #{elapsed_time} sec"
          end
          print "\x08" * output.length
          print output
          $stdout.flush
        end

        if success
          puts
          puts "Continuous integration: success!"
          if ci.jenkins? && File.exist?("coverage")
            puts "Downloading test coverage from CI..."
            download_ci_test_coverage
          end
          puts "Deploying..."
        else
          puts
          puts ci.last_response
          puts ci.console
          puts red("Automated tests failed!")
          exit 1
        end

      else
        puts red("No CI found for #{project_name}!")
        puts "Re-run with --skip-ci to bypass CI, if you absolutely must, and know what you're doing."
        exit 1
      end
    end

    desc "open [SERVER=production]", "opens the url in the web browser."
    def open server=nil
      server ||= config.servers.key?(:production) ? :production : :staging
      server = config.servers[server.to_sym]
      exec "xdg-open #{server.ping.first}"
    end

    desc "hurt", "reruns a command until it fails"
    def hurt *args
      1.upto(Float::INFINITY) do |count|
        puts "Running attempt #{count}"
        system *args
        unless $?.success?
          puts "Ran #{count-1} times before failing"
          break
        end
      end
    end

    method_options %w[home] => :boolean
    desc "ssh [TO=production]", "logs into the specified server via SSH"
    def ssh to=:production
      command = "exec $SHELL -l"
      if to == "theia" && !options["home"]
        server = config.servers[:theia]
        command = %(bash -lic "exec ./vagrant \\"cd #{server.path} && #{command}\\"")
        exec ssh_command(to, command, home: true)
      else
        exec ssh_command(to, command, home: options["home"])
      end
    end

    desc "install", "copies bin/setup and bin/ci scripts into current project."
    def install
      install_files_path = File.expand_path(File.join(__dir__, "../install_files/*"))
      system "cp -R #{install_files_path} bin/"
      github_files_path = File.expand_path(File.join(__dir__, "../install_files/.github"))
      system "cp -R #{github_files_path} ./"
    end

    desc "setup", "installs app in nginx"
    def setup
      path = "/etc/nginx/sites-available/#{project_name}"
      dest_path = path.sub("sites-available", "sites-enabled")
      server_name = "#{project_name}.localhost"

      create_file path, <<~NGINX
        server {
          listen 80;
          server_name #{server_name};

          root #{Dir.pwd}/public;
          passenger_enabled on;

          location ~* \\.(ico|css|js|gif|jp?g|png|webp) {
            access_log off;
            if ($request_filename ~ "-[0-9a-f]{32}\\.") {
              expires max;
              add_header Cache-Control public;
            }
          }
          gzip_static on;
        }
      NGINX

      FileUtils.ln_sf(path, dest_path) if !File.exist?(dest_path)
      run "service nginx restart"
    rescue Errno::EACCES
      raise InvocationError.new("please re-run with sudo")
    end

    desc "ping [SERVER=production]", "hits the server over http to verify that its up."
    def ping server=:production
      server = config.servers[server.to_sym]
      down_urls = Bard::Ping.call(server)
      down_urls.each { |url| puts "#{url} is down!" }
      exit 1 if down_urls.any?
    end

    desc "command <command> --on=production", "run the given command on the remote server"
    method_options %w[on] => :string
    def command command
      default_from = config.servers.key?(:production) ? "production" : "staging"
      on = options.fetch(:on, default_from)
      server = config.servers[on.to_sym]
      remote_command = Bard::RemoteCommand.new(server, command).local_command
      run_crucial remote_command, verbose: true
    end

    desc "master_key --from=production --to=local", "copy master key from from to to"
    method_options %w[from] => :string, %w[to] => :string
    def master_key
      default_from = config.servers.key?(:production) ? "production" : "staging"
      from = options.fetch(:from, default_from)
      to = options.fetch(:to, "local")
      if to == "local"
        copy :from, from, "config/master.key"
      end
      if from == "local"
        copy :to, to, "config/master.key"
      end
    end

    desc "download_ci_test_coverage", "download latest test coverage information from CI"
    def download_ci_test_coverage
      rsync :from, :ci, "coverage"
    end

    desc "vim", "open all files that have changed since master"
    def vim branch="master"
      exec "vim -p `git diff #{branch} --name-only | grep -v sass$ | tac`"
    end

    def self.exit_on_failure? = true

    include Term::ANSIColor

    private

    def config
      @config ||= Bard::Config.new(project_name, path: "bard.rb")
    end

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
      server = config.servers.fetch(server_name.to_sym)
      Bard::RemoteCommand.new(server, command, home).local_command
    end

    def copy direction, server_name, path, verbose: false
      server = config.servers.fetch(server_name.to_sym)

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
      from = config.servers.fecth(from_name.to_sym)
      to = config.servers.fetch(to_name.to_sym)
      raise NotImplementedError if from.gateway || to.gateway || from.ssh_key || to.ssh_key

      from_uri = URI.parse("ssh://#{from.ssh}")
      from_str = "scp://#{from_uri.user}@#{from_uri.host}:#{from_uri.port || 22}/#{from.path}/#{path}"

      to_uri = URI.parse("ssh://#{to.ssh}")
      to_str = "scp://#{to_uri.user}@#{to_uri.host}:#{to_uri.port || 22}/#{to.path}/#{path}"

      command = "scp -o ForwardAgent=yes #{from_str} #{to_str}"

      run_crucial command, verbose: verbose
    end

    def rsync direction, server_name, path, verbose: false
      server = config.servers.fetch(server_name.to_sym)

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
      from = config.servers.fetch(from_name.to_sym)
      to = config.servers.fetch(to_name.to_sym)
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
end
