$:.unshift File.expand_path(File.dirname(__FILE__))
require 'term/ansicolor'
require 'systemu'
require 'grit'

require 'bard/git'
require 'bard/io'

class Bard < Thor
  include BardGit
  include BardIO

  desc "check", "check environment for missing dependencies"
  def check
    required = Hash.new
    required['bard'] = `gem list bard --remote`[/[0-9]+\.[0-9]+\.[0-9]+/]
    required['git'] = '1.6.0'
    required['rubygems'] = '1.3.4'
    required['ruby'] = '1.8.6'

    actual = Hash.new
    actual['bard'] = `gem list bard`[/[0-9]+\.[0-9]+\.[0-9]+/]
    actual['git'] = `git --version`[/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/]
    actual['rubygems'] = `gem --version`.chomp
    actual['ruby'] = `ruby --version`[/[0-9]+\.[0-9]+\.[0-9]+/]

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
    puts changed_files.inspect
   
    if changed_files.any? { |f| f =~ %r(^db/migrate/.+) }
      run_crucial "rake db:migrate"
      run_crucial "rake db:migrate RAILS_ENV=test"
    end
     
    if changed_files.any? { |f| f == ".gitmodules" }
      run_crucial "git submodule sync"
      run_crucial "git submodule init"
    end
    run_crucial "git submodule update"
   
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
end
