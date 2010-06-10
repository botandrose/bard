Capistrano::Configuration.instance(:must_exist).load do
  role :staging, "www@staging.botandrose.com"

  namespace "data" do
    namespace "pull" do
      desc "pull data"
      task "default" do
        run "cd #{application} && rake db:dump && gzip -9f db/data.sql"
        transfer :down, "#{application}/db/data.sql.gz", "db/data.sql.gz"
        system "gunzip -f db/data.sql.gz && rake db:load"
      end
    end
  end

  desc "push app from staging to production"
  task :deploy, :roles => :production do
    system "git push github" if `git remote` =~ /\bgithub\b/
    run "cd #{application} && git pull origin master && rake bootstrap:production"
    puts "Deploy Succeeded"
  end
end
