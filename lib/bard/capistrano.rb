require 'uri'

Capistrano::Configuration.instance(:must_exist).load do
  require "rvm/capistrano"
  set :rvm_type, :user

  role :staging, "www@staging.botandrose.com:22022"
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
  end

  after 'data:pull', 'data:pull:assets'

  desc "push app to production"
  task :deploy, :roles => :production do
    system "git push github" if `git remote` =~ /\bgithub\b/
    run "cd #{application} && git pull origin master && bundle && bundle exec rake bootstrap:production"
  end

  desc "push app to staging"
  task :stage, :roles => :staging do
    branch = ENV.has_key?("BRANCH") ? ENV["BRANCH"] : "integration"
    run "cd #{application} && git fetch && git checkout -f origin/#{branch} && bundle && bundle exec rake bootstrap"
  end
end
