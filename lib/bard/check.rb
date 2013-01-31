class Bard < Thor
  private
    def auto_update!
      match = `curl -s http://rubygems.org/api/v1/gems/bard.json`.match(/"version":"([0-9.]+)"/)
      return unless match
      required = match[1]
      if Bard::VERSION != required
        original_command = [ENV["_"], @_invocations[Bard].first, ARGV].flatten.join(" ")
        puts "bard gem is out of date... updating to new version"
        exec "gem install bard && #{original_command}"
      end
      if options.verbose?
        puts green("#{"bard".ljust(9)} (#{Bard::VERSION})") 
      end
    end

    def check_project(project)
      errors = []
      Dir.chdir project do
        status, stdout, stderr = systemu "rake db:abort_if_pending_migrations"
        errors << "missing config/database.yml, adapt from config/database.sample.yml." if stderr.include? "config/database.yml"
        errors << "missing config/database.sample.yml, please complain to micah" if not File.exist? "config/database.sample.yml"
        errors << "missing database, please run `rake db:create db:migrate" if stderr.include? "Unknown database"
        errors << "pending migrations, please run `rake db:migrate`" if stdout.include? "pending migrations"

        errors << "missing submodule, please run git submodule update --init" if `git submodule status` =~ /^-/
        errors << "submodule has a detached head, please complain to micah" unless system 'git submodule foreach "git symbolic-ref HEAD 1>/dev/null 2>/dev/null"'

        errors << "missing gems, please run `rake gems:install`" if `rake gems` =~ /\[ \]/

        errors << "missing integration branch, please complain to micah" if `git branch` !~ /\bintegration\b/
        unless ENV['RAILS_ENV'] == "staging"
          errors << "integration branch isnt tracking the remote integration branch, please run `grb track integration`" if `git config branch.integration.merge` !~ %r%\brefs/heads/integration\b%
        end
        errors << "you shouldn't be working on the master branch, please work on the integration branch" if current_branch == "master"

        errors << "Capfile should not be gitignored" if File.read(".gitignore") =~ /\bCapfile\b/
        errors << "config/deploy.rb should not be gitignored" if File.read(".gitignore") =~ /\bconfig\/deploy\.rb\b/
        errors << "missing bard rake tasks, please complain to micah" if File.read("Rakefile") !~ /\bbard\/rake\b/
        errors << "missing bard capistrano tasks, please complain to micah" if File.read("Capfile") !~ /\bbard\/capistrano\b/
      end

      if not errors.empty?
        fatal "#{errors.length} problems detected:\n  #{errors.join("\n  ")}"
      else
        puts green("No problems detected in project: #{project}")
        unless ENV['RAILS_ENV'] == "staging"
          puts "please run it on the staging server by typing `cap shell` and then `bard check [PROJECT_NAME]`"
        end
      end
    end
end
