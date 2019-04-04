require 'uri'

Capistrano::Configuration.instance(:must_exist).load do
  require "rvm/capistrano"
  set :rvm_type, :user
  ruby_version = File.read(".ruby-version").chomp
  ruby_gemset = File.read(".ruby-gemset").chomp
  set :rvm_ruby_string, [ruby_version, ruby_gemset].join("@")

  set :application, File.basename(Dir.pwd)

  role :staging, "www@staging.botandrose.com:22022"
  role :ci, "jenkins@ci.botandrose.com:22022"

  set :asset_paths, []

  namespace "data" do
    namespace "pull" do
      desc "pull data"
      task "default" do
        run "cd #{application} && bundle exec rake db:dump && gzip -9f db/data.sql"
        transfer :down, "#{application}/db/data.sql.gz", "db/data.sql.gz"
        system "gunzip -f db/data.sql.gz && bundle exec rake db:load"
      end

      desc "sync the static assets"
      task "assets" do
        uri = URI.parse("ssh://#{roles[ENV['ROLES'].to_sym].first.to_s}")
        portopt = "-e'ssh -p#{uri.port}'" if uri.port

        [asset_paths].flatten.each do |path|
          dest_path = path.dup
          dest_path.sub! %r(/[^/]+$), '/'
          system "rsync #{portopt} --delete -avz #{uri.user}@#{uri.host}:#{application}/#{path} #{dest_path}"
        end
      end
    end

    namespace "push" do
      desc "push data"
      task "default" do
        system "bundle exec rake db:dump && gzip -9f db/data.sql"
        transfer :up, "db/data.sql.gz", "#{application}/db/data.sql.gz"
        run "cd #{application} && gunzip -f db/data.sql.gz && bundle exec rake db:load"
      end

      desc "sync the static assets"
      task "assets" do
        uri = URI.parse("ssh://#{roles[ENV['ROLES'].to_sym].first.to_s}")
        portopt = "-e'ssh -p#{uri.port}'" if uri.port

        [asset_paths].flatten.each do |path|
          dest_path = path.dup
          dest_path.sub! %r(/[^/]+$), '/'
          system "rsync #{portopt} --delete -avz #{path} #{uri.user}@#{uri.host}:#{application}/#{dest_path}"
        end
      end
    end
  end

  after 'data:pull', 'data:pull:assets'
  after 'data:push', 'data:push:assets'

  desc "push app to production"
  task :deploy do
    deploy_roles = roles.keys.include?(:production) ? :production : :staging
    ENV["ROLES"] = deploy_roles.to_s
    find_and_execute_task "rvm:install_ruby"
    system "git push github" if `git remote` =~ /\bgithub\b/
    run "cd #{application} && git pull origin master && bin/setup", roles: deploy_roles
  end

  desc "push app to staging"
  task :stage do
    ENV["ROLES"] = "staging"
    find_and_execute_task "rvm:install_ruby"
    branch = ENV.fetch("BRANCH")
    run "cd #{application} && git fetch && git checkout -f origin/#{branch} && bin/setup", :roles => :staging
  end

  desc "test app for downtime"
  task :ping do
    role = ENV.fetch("ROLES", "production").to_sym
    uri = URI.parse("ssh://#{roles[role].first.to_s}")
    command = "curl -sfLI #{uri.hostname} 2>&1 1>/dev/null"
    unless system command
      puts "#{uri.hostname} is down!"
      exit 1
    end
  end

  desc "log in via ssh"
  task :ssh do
    role = ENV['ROLES'].to_sym
    path = role == :ci ? "jobs/#{application}/workspace" : application
    uri = URI.parse("ssh://#{roles[role].first.to_s}")
    exec "ssh -t #{"-p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} '#{"cd #{path} && " unless ENV['NOCD']}exec $SHELL -l'"
  end

  desc "download latest test coverage information from CI"
  task :download_ci_test_coverage do
    uri = URI.parse("ssh://#{roles[:staging].first}")
    portopt = "-e'ssh -p#{uri.port}'" if uri.port
    system "rsync #{portopt} --delete -avz #{uri.user}@#{uri.host}:~jenkins/jobs/#{application}/workspace/coverage ./"
  end
end
