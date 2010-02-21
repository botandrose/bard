Capistrano::Configuration.instance(:must_exist).load do
  role :staging, "staging@staging.botandrose.com"

  namespace "data" do
    namespace "pull" do
      desc "pull data from production"
      task :default, :roles => :production do
        data_pull :production
      end
      task :staging, :roles => :staging do
        data_pull :staging
      end
    end
  end

  def data_pull(env)
    config = YAML::load(File.open("config/database.yml"))
    source = config[env.to_s]
    target = config[ENV['RAILS_ENV'] || "development"]
    run "cd #{application} && mysqldump -u#{source["username"]} --password=#{source["password"]} '#{source["database"]}' > db/data.sql && gzip -9f db/data.sql"
    transfer :down, "#{application}/db/data.sql.gz", "db/data.sql.gz"
    run "cd #{application} && rm db/data.sql.gz"
    system "gunzip -f db/data.sql.gz"
    system "echo 'DROP DATABASE `#{target["database"]}`; CREATE DATABASE `#{target["database"]}`;' | mysql -u#{target["username"]} --password=#{target["password"]}"
    system "mysql -u#{target["username"]} --password=#{target["password"]} '#{target["database"]}' < db/data.sql"
    # system "rm db/data.sql"
  end

  namespace "deploy" do
    desc "push app from staging to production"
    task :default, :roles => :production do
      system "git push github" if `git remote` =~ /\bgithub\b/
      run "cd #{application} && git pull"
      run "cd #{application} && rake gems:install" if File.exist?("Rakefile")
      run "cd #{application} && script/runner 'Sass::Plugin.options[:always_update] = true; Sass::Plugin.update_stylesheets'" if File.exist?("public/stylesheets/sass") or File.exist?("app/sass")
      run "cd #{application} && rake asset:packager:build_all" if File.exist?("vendor/plugins/asset_packager")
      run "cd #{application} && git submodule init && git submodule update" if File.exist?(".gitmodules")
      run "cd #{application} && rake db:migrate && rake restart" if File.exist?("Rakefile")
      puts "Deploy Succeeded"
    end
  end
end
