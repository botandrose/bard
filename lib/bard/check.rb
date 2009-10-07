class Bard < Thor
  private
    def check_dependencies
      required = {
        'bard'     => Net::HTTP.get(URI.parse("http://gemcutter.org/gems/bard.json")).match(/"version":"([0-9.]+)"/)[1],
        'git'      => '1.6.4',
        'rubygems' => '1.3.4',
        'ruby'     => '1.8.6'
      }
      actual = {
        'bard'     =>  Bard::VERSION,
        'git'      => `git --version`[/[0-9.]+/],
        'rubygems' =>  Gem::VERSION,
        'ruby'     =>  RUBY_VERSION
      }
      help = {
        'bard'     => 'please type `gem install bard` to update',
        'git'      => 'please visit http://git-scm.com/download and install the appropriate package for your architecture',
        'rubygems' => 'please type `gem update --system` to update',
        'ruby'     => 'um... ask micah?'
      }

      %w(bard git rubygems ruby).each do |pkg|
        if actual[pkg] < required[pkg]
          puts red("#{pkg.ljust(9)} (#{actual[pkg]}) ... NEED (#{required[pkg]})")
          puts red("  #{help[pkg]}")
        else
          puts green("#{pkg.ljust(9)} (#{actual[pkg]})")
        end
      end
    end

    def check_project(project)
      errors = []
      warnings = []
      Dir.chdir project do
        status, stdout, stderr = systemu "rake db:abort_if_pending_migrations"
        errors << "missing config/database.yml, adapt from config/database.sample.yml." if stderr.include? "config/database.yml"
        errors << "missing config/database.sample.yml, please complain to micah" if not File.exist? "config/database.sample.yml"
        errors << "missing database, please run `rake db:create db:migrate" if stderr.include? "Unknown database"
        errors << "pending migrations, please run `rake db:migrate`" if stdout.include? "pending migrations"

        errors << "missing submodule, please run git submodule update --init" if `git submodule status` =~ /^-/
        errors << "submodule has a detached head, please complain to micah" unless system 'git submodule foreach "git symbolic-ref HEAD"'

        errors << "missing gems, please run `rake gems:install`" if `rake gems` =~ /\[ \]/

        errors << "missing integration branch, please complain to micah" if `git branch` !~ /\bintegration\b/
        errors << "integration branch isnt tracking the remote integration branch, please run `grb track integration`" if `git config branch.integration.merge` !~ %r%\brefs/heads/integration\b%
        errors << "you shouldn't be working on the master branch, please work on the integration branch" if `cat .git/HEAD`.include? "refs/heads/master"

        if ENV['RAILS_ENV'] == "staging"
          if not File.exist? ".git/hooks/post-receive" 
            errors << "missing git hook, please complain to micah" 
          else
            errors << "unexecutable git hook, please complain to micah" unless File.executable? ".git/hooks/post-receive" 
            errors << "improper git hook, please complain to micah" unless File.read(".git/hooks/post-receive").include? "bard stage $@"
          end
          errors << "the git config variable receive.denyCurrentBranch is not set to ignore, please complain to micah" if `git config receive.denyCurrentBranch`.chomp != "ignore"
        end

        warnings << "RAILS_ENV is not set, please complain to micah" if ENV['RAILS_ENV'].nil? or ENV['RAILS_ENV'].empty?
      end

      if not errors.empty?
        fatal "#{errors.length} problems detected:\n  #{errors.join("\n  ")}"
      elsif not warnings.empty?
        warn "#{warnings.length} potential problems detected:\n  #{warnings.join("\n  ")}"
      else
        puts green("No problems detected in project: #{project}")
        if ENV['RAILS_ENV'] != "staging"
          puts "please run it on the staging server by typing `cap shell` and then `bard check [PROJECT_NAME]`"
        end
      end
    end
end
