class Bard < Thor
  private
    def auto_update!
      original_command = [ENV["_"], @_invocations[Bard], ARGV].flatten.join(" ")
      required = `curl -s http://gemcutter.org/api/v1/gems/bard.json`.match(/"version":"([0-9.]+)"/)[1]
      if Versionomy.parse(Bard::VERSION) < Versionomy.parse(required)
        original_command = [ENV["_"], @_invocations[Bard], ARGV].flatten.join(" ")
        puts "bard gem is out of date... updating to new version"
        exec "gem install bard && #{original_command}"
      end
    end

    def check_dependencies
      required = {
        'git'      => '1.6.4',
        'rubygems' => '1.3.4',
        'ruby'     => '1.8.7'
      }
      actual = {
        'git'      => `git --version`[/[0-9.]+/],
        'rubygems' =>  Gem::VERSION,
        'ruby'     =>  RUBY_VERSION
      }
      help = {
        'git'      => 'please visit http://git-scm.com/download and install the appropriate package for your architecture',
        'rubygems' => 'please type `gem update --system` to update',
        'ruby'     => 'ruby 1.8.7 is required for all projects now. talk to micah for upgrade help'
      }

      errors = []
      %w(git rubygems ruby).each do |pkg|
        if Versionomy.parse(actual[pkg]) < Versionomy.parse(required[pkg])
          errors << red("#{pkg.ljust(9)} (#{actual[pkg]}) ... NEED (#{required[pkg]})\n  #{help[pkg]}")
        elsif options.verbose?
          puts green("#{pkg.ljust(9)} (#{actual[pkg]})") 
        end
      end
      if not errors.empty?
        fatal "#{errors.length} problems detected:\n  #{errors.join("\n  ")}"
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
