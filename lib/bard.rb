$:.unshift File.expand_path(File.dirname(__FILE__))
require 'term/ansicolor'
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
      'bard'     => `gem list bard --remote`[/[0-9]+\.[0-9]+\.[0-9]+/],
      'git'      => '1.6.0',
      'rubygems' => '1.3.4',
      'ruby'     => '1.8.6'
    }
    actual = {
      'bard'     => `gem list bard`[/[0-9]+\.[0-9]+\.[0-9]+/],
      'git'      => `git --version`[/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/],
      'rubygems' => `gem --version`.chomp,
      'ruby'     => `ruby --version`[/[0-9]+\.[0-9]+\.[0-9]+/]
    }

    %w(bard git rubygems ruby).each do |pkg|
      if actual[pkg] < required[pkg]
        puts red("#{pkg.ljust(9)} (#{actual[pkg]}) ... NEED (#{required[pkg]})")
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
    run_crucial "git submodule update --merge"
   
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

  private
    def check_project(project)
      errors = []
      warnings = []
      Dir.chdir project do
        status, stdout, stderr = systemu "rake db:abort_if_pending_migrations"
        errors << "missing config/database.yml" if stderr.include? "config/database.yml"
        errors << "missing database" if stderr.include? "Unknown database"
        errors << "pending migrations" if stdout.include? "pending migrations"

        errors << "missing submodule" if `git submodule status` =~ /^-/
        errors << "submodule has a detached head" unless system 'git submodule foreach "git symbolic-ref HEAD"'
        errors << "missing gems" if `rake gems` =~ /\[ \]/
        errors << "you shouldn't be working on the master branch" if `cat .git/HEAD`.include? "refs/heads/master"
        errors << "missing integration branch" if `git branch` !~ /\bintegration\b/

        if ENV['RAILS_ENV'] == "staging"
          if File.exist? ".git/hooks/post-receive" 
            errors << "unexecutable git hook" unless File.executable? ".git/hooks/post-receive" 
            errors << "improper git hook" unless File.read(".git/hooks/post-receive").include? "bard stage $@"
          else
            errors << "missing git hook" 
          end
          errors << "the git config variable receive.denyCurrentBranch is not set to ignore" if `git config receive.denyCurrentBranch`.chomp != "ignore"
        end

        warnings << "RAILS_ENV is not set" if ENV['RAILS_ENV'].nil? or ENV['RAILS_ENV'].empty?
      end

      if not errors.empty?
        fatal "#{errors.length} problems detected:\n  #{errors.join("\n  ")}"
      elsif not warnings.empty?
        warn "#{warnings.length} potential problems detected:\n  #{warnings.join("\n  ")}"
      else
        puts green("No problems detected in project: #{project}")
      end
    end
end
