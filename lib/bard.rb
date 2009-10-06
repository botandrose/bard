$:.unshift File.expand_path(File.dirname(__FILE__))
require 'term/ansicolor'
require 'net/http'
require 'systemu'
require 'grit'
require 'thor'

require 'bard/git'
require 'bard/io'

class Bard < Thor
  include BardGit
  include BardIO

  desc "check [PROJECT]", "check PROJECT or environment for missing dependencies"
  def check(project = nil)
    return check_project(project) if project

    required = {
      'bard'     => Net::HTTP.get(URI.parse("http://gemcutter.org/gems/bard.json")).match(/"version":"([0-9.]+)"/)[1],
      'git'      => '1.6.4',
      'rubygems' => '1.3.4',
      'ruby'     => '1.8.6'
    }
    actual = {
      'bard'     => `gem list bard`[/[0-9]+\.[0-9]+\.[0-9]+/],
      'git'      => `git --version`[/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/],
      'rubygems' => `gem --version`.chomp,
      'ruby'     => `ruby --version`[/[0-9]+\.[0-9]+\.[0-9]+/]
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

  desc "pull", "pull changes to your local machine"
  def pull
    ensure_integration_branch!
    ensure_clean_working_directory!

    unless fast_forward_merge?
      warn "Someone has pushed some changes since you last pulled.\n  Please ensure that your changes didnt break stuff."
    end

    run_crucial "git pull --rebase origin integration"

    changed_files = run_crucial("git diff #{@common_ancestor} origin/integration --diff-filter=ACDMR --name-only").split("\n") 
   
    if changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
      run_crucial "rake db:migrate"
      run_crucial "rake db:migrate RAILS_ENV=test"
    end
     
    if changed_files.any? { |f| f == ".gitmodules" }
      run_crucial "git submodule sync"
      run_crucial "git submodule init"
    end
    run_crucial "git submodule update --rebase"
   
    if changed_files.any? { |f| f =~ %r(^config/environment.+) }
      run_crucial "rake gems:install"
    end

    system "touch tmp/restart.txt"
  end

  desc "push", "push local changes out to the remote"
  def push
    ensure_integration_branch!
    ensure_clean_working_directory!

    if submodule_dirty?
      fatal "Cannot push changes: You have uncommitted changes to a submodule!\n  Please see Micah about this."
    end

    if submodule_unpushed?
      fatal "Cannot push changes: You have unpushed changes to a submodule!\n  Please see Micah about this."
    end

    unless fast_forward_merge?
      fatal "Someone has pushed some changes since you last pulled.\n  Kindly run bard pull, ensure that your your changes still work.\n  Then run bard push again."
    end

    run_crucial "git push origin integration", true
    
    # git post-receive hook runs stage task below
  end

  desc "deploy", "pushes, merges integration branch into master and deploys it to production"
  def deploy
    invoke :push
    run_crucial "git fetch origin"
    run_crucial "git checkout master"
    run_crucial "git pull --rebase origin master"
    if not fast_forward_merge? "master", "integration"
      fatal "master has advanced since last deploy, probably due to a bugfix. rebase your integration branch on top of it, and check for breakage."
    end

    run_crucial "git merge integration"
    run_crucial "git push origin master"
  end

  if ENV['RAILS_ENV'] == "staging"
    desc "stage", "!!! INTERNAL USE ONLY !!! reset HEAD to integration, update submodules, run migrations, install gems, restart server"
    def stage
      if ENV['GIT_DIR'] == '.'
        # this means the script has been called as a hook, not manually.
        # get the proper GIT_DIR so we can descend into the working copy dir;
        # if we don't then `git reset --hard` doesn't affect the working tree.
        Dir.chdir '..' 
        ENV['GIT_DIR'] = '.git'
      end

      run_crucial "git reset --hard"

      # find out the current branch
      head = File.read('.git/HEAD').chomp
      # abort if we're on a detached head
      exit unless head.sub! 'ref: ', ''
      if head == "master"
        run_crucial "cap deploy"
      else
        revs = gets.split ' '  
        old_rev, new_rev = revs if head == revs.pop

        changed_files = run_crucial("git diff #{old_rev} #{new_rev} --diff-filter=ACMRD --name-only").split("\n") 

        if changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
          run_crucial "rake db:migrate RAILS_ENV=staging"
          run_crucial "rake db:migrate RAILS_ENV=test"
        end
         
        if changed_files.any? { |f| f == ".gitmodules" }
          run_crucial "git submodule sync"
          run_crucial "git submodule init"
        end
        system "git submodule update"
       
        if changed_files.any? { |f| f =~ %r(^config/environment.+) }
          run_crucial "rake gems:install"
        end

        system "touch tmp/restart.txt"
      end
    end
  end

  private
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
