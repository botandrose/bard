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

      desc "pull data from production"
      task :yml, :roles => :production do
        run "cd #{application} && rake db:data:dump && gzip -9f db/data.yml"
        transfer :down, "#{application}/db/data.yml.gz", "db/data.yml.gz"
        system "gunzip -f db/data.yml.gz"
        system "rake db:data:load"
      end
    end
  end

  def data_pull(env)
    config = YAML::load(File.open("config/database.yml"))
    source = config[env.to_s]
    target = config["development"]
    run "cd #{application} && mysqldump -u#{source["username"]} #{"-p#{source["password"]}" if source["password"]} '#{source["database"]}' > db/data.sql && gzip -9f db/data.sql"
    transfer :down, "#{application}/db/data.sql.gz", "db/data.sql.gz"
    run "cd #{application} && rm db/data.sql.gz"
    system "gunzip -f db/data.sql.gz"
    system "echo 'DROP DATABASE `#{target["database"]}`; CREATE DATABASE `#{target["database"]}`;' | mysql -u#{target["username"]}"
    system "mysql -u#{target["username"]} '#{target["database"]}' < db/data.sql"
    # system "rm db/data.sql"
  end

  namespace "deploy" do
    desc "push app from staging to production"
    task :default, :roles => :production do
      begin

        if `curl -s -I http://integrity.botandrose.com/#{application}` !~ /\b404\b/
          puts "Integrity: verifying build..."
          system "curl -sX POST http://integrity.botandrose.com/#{application}/builds"
          while true
            response = `curl -s http://integrity.botandrose.com/#{application}`
            break unless response =~ /div class='(building|pending)' id='last_build'/
            sleep(1)
          end
          case response
            when /div class='failed' id='last_build'/ then raise TestsFailedError
            when /div class='success' id='last_build'/ then success "Integrity: success! deploying to production"
            else raise "Unknown response from CI server:\n#{response}"
          end
        end

        system "git push" if `git remote show origin` =~ /github\.com/
        run "cd #{application} && git pull"
        run "cd #{application} && rake gems:install" if File.exist?("Rakefile")
        run "cd #{application} && script/runner 'Sass::Plugin.options[:always_update] = true; Sass::Plugin.update_stylesheets'" if File.exist?("public/stylesheets/sass") or File.exist?("app/sass")
        run "cd #{application} && rake asset:packager:build_all" if File.exist?("vendor/plugins/asset_packager")
        run "cd #{application} && git submodule init && git submodule update" if File.exist?(".gitmodules")
        run "cd #{application} && rake db:migrate && rake restart" if File.exist?("Rakefile")
        success "Deploy Succeeded"

      rescue BardError => e
        handle_error e
      end
    end

    def readline(prompt)
      STDOUT.print(prompt)
      STDOUT.flush
      STDIN.gets
    end
    
    def handle_error(error)
      name = error.message.split('::').last.gsub(/([A-Z])/, " \\1").gsub(/^ /,'').gsub(/ Error/, '')
      failure "!!! Deploy Error: #{name}"
    end
  end

  ## ERROR HANDLING

  def handle_error(error)
    name = error.message.split('::').last.gsub(/([A-Z])/, " \\1").gsub(/^ /,'').gsub(/ Error/, '')
    failure "!!! Deploy Error: #{name}"
  end

  class BardError < Capistrano::Error; end
  class TestsFailedError < BardError; end
  class WorkingDirectoryDirtyError < BardError; end
  class StagingWorkingDirectoryDirtyError < BardError; end
  class NonFastForwardError < BardError; end

  def success(msg)
    puts "#{GREEN}#{msg}#{DEFAULT}"
  end

  def failure(msg)
    abort "#{RED}#{msg}#{DEFAULT}"
  end

  GREEN = "\033[1;32m"
  RED = "\033[1;31m"
  DEFAULT = "\033[0m"
end
