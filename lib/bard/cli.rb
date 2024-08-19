# this file gets loaded in the CLI context, not the Rails boot context

require "thor"
require "bard/git"
require "bard/ci"
require "bard/copy"
require "bard/github"
require "bard/ping"
require "bard/config"
require "bard/command"
require "term/ansicolor"
require "open3"
require "uri"

module Bard
  class CLI < Thor
    include Term::ANSIColor

    class_option :verbose, type: :boolean, aliases: :v

    desc "data --from=production --to=local", "copy database and assets from from to to"
    option :from, default: "production"
    option :to, default: "local"
    def data
      from = config[options[:from]]
      to = config[options[:to]]

      if to.key == :production
        url = to.ping.first
        puts yellow "WARNING: You are about to push data to production, overwriting everything that is there!"
        answer = ask("If you really want to do this, please type in the full HTTPS url of the production server:")
        if answer != url
          puts red("!!! ") + "Failed! We expected #{url}. Is this really where you want to overwrite all the data?"
          exit 1
        end
      end

      puts "Dumping #{from.key} database to file..."
      Bard::Command.run! "bin/rake db:dump", on: from

      puts "Transfering file from #{from.key} to #{to.key}..."
      Bard::Copy.file "db/data.sql.gz", from: from, to: to, verbose: true

      puts "Loading file into #{to.key} database..."
      Bard::Command.run! "bin/rake db:load", on: to

      config.data.each do |path|
        puts "Synchronizing files in #{path}..."
        Bard::Copy.dir path, from: from, to: to, verbose: true
      end
    end

    desc "stage [branch=HEAD]", "pushes current branch, and stages it"
    def stage branch=Git.current_branch
      unless config.servers.key?(:production)
        raise Thor::Error.new("`bard stage` is disabled until a production server is defined. Until then, please use `bard deploy` to deploy to the staging server.")
      end

      Bard::Command.run! "git push -u origin #{branch}", verbose: true
      command = "git fetch && git checkout -f origin/#{branch} && bin/setup"
      Bard::Command.run! command, on: config[:staging]
      puts green("Stage Succeeded")

      ping :staging
    end

    option :"skip-ci", type: :boolean
    option :"local-ci", type: :boolean
    desc "deploy [TO=production]", "checks that current branch is a ff with master, checks with ci, merges into master, deploys to target, and then deletes branch."
    def deploy to=:production
      branch = Git.current_branch

      if branch == "master"
        Bard::Command.run! "git push origin #{branch}:#{branch}" if !Git.up_to_date_with_remote?(branch)
        invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

      else
        Bard::Command.run! "git fetch origin master:master"

        unless Git.fast_forward_merge?("origin/master", branch)
          puts "The master branch has advanced. Attempting rebase..."
          Bard::Command.run! "git rebase origin/master"
        end

        Bard::Command.run! "git push -f origin #{branch}:#{branch}"

        invoke :ci, [branch], options.slice("local-ci") unless options["skip-ci"]

        Bard::Command.run! "git push origin #{branch}:master"
        Bard::Command.run! "git fetch origin master:master"
      end

      if `git remote` =~ /\bgithub\b/
        Bard::Command.run! "git push github"
      end

      command = "git pull origin master && bin/setup"
      Bard::Command.run! command, on: config[to]

      puts green("Deploy Succeeded")

      if branch != "master"
        puts "Deleting branch: #{branch}"
        Bard::Command.run! "git push --delete origin #{branch}"

        if branch == Git.current_branch
          Bard::Command.run! "git checkout master"
        end

        Bard::Command.run! "git branch -D #{branch}"
      end

      ping to
    end

    option :"local-ci", type: :boolean
    option :status, type: :boolean
    desc "ci [branch=HEAD]", "runs ci against BRANCH"
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

    desc "open [server=production]", "opens the url in the web browser."
    def open server=:production
      exec "xdg-open #{config[server].ping.first}"
    end

    desc "hurt <command>", "reruns a command until it fails"
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

    option :home, type: :boolean
    desc "ssh [to=production]", "logs into the specified server via SSH"
    def ssh to=:production
      Bard::Command.exec! "exec $SHELL -l", on: config[to], home: options[:home]
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

    desc "ping [server=production]", "hits the server over http to verify that its up."
    def ping server=:production
      server = config[server]
      down_urls = Bard::Ping.call(config[server])
      down_urls.each { |url| puts "#{url} is down!" }
      exit 1 if down_urls.any?
    end

    option :on, default: "production"
    desc "command <command> --on=production", "run the given command on the remote server"
    def command command
      Bard::Command.run! remote_command, on: config[options[:on]], verbose: true
    end

    desc "master_key --from=production --to=local", "copy master key from from to to"
    option :from, default: "production"
    option :to, default: "local"
    def master_key
      Bard::Copy.file "config/master.key", from: config[options[:from]], to: config[options[:to]]
    end

    desc "vim [branch=master]", "open all files that have changed since master"
    def vim branch="master"
      exec "vim -p `git diff #{branch} --name-only | grep -v sass$ | tac`"
    end

    def self.exit_on_failure? = true

    private

    def config
      @config ||= Bard::Config.new(project_name, path: "bard.rb")
    end

    def project_name
      @project_name ||= File.expand_path(".").split("/").last
    end
  end
end

