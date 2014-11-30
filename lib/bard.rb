$:.unshift File.expand_path(File.dirname(__FILE__))

module Bard; end

require "bard/base"
require "bard/error"
require "bard/git"
require "bard/ci"

class Bard::CLI < Thor
  include Bard::CLI::Git

  desc "data [FROM=production, TO=local]", "copy database and assets from FROM to TO"
  def data(from = "production", to = "local")
    exec "cap _2.5.10_ data:pull ROLES=#{from}" if to == "local"
    exec "cap _2.5.10_ data:push ROLES=#{to}" if from == "local"
  end

  method_options %w( verbose -v ) => :boolean
  desc "pull", "pull changes to your local machine"
  def pull
    run_crucial "git pull --rebase origin #{current_branch}", options.verbose?
    run_crucial "bundle && bundle exec rake bootstrap", options.verbose?
  end

  method_options %w( verbose -v ) => :boolean
  desc "stage", "pushes current branch, and stages it"
  def stage
    run_crucial "git push -u origin #{current_branch}", true
    run_crucial "cap _2.5.10_ stage BRANCH=#{current_branch}", options.verbose?

    puts green("Stage Succeeded")
  end

  method_options %w( verbose -v ) => :boolean
  desc "deploy", "checks that branch is a ff with master, checks with ci, and then merges into master and deploys to production, and deletes branch."
  def deploy
    branch = current_branch

    run_crucial "git fetch origin"
    raise MasterNonFastForwardError if not fast_forward_merge? "origin/master", "master"

    if branch == "master"
      run_crucial "git push origin master"
      invoke :ci

    else
      run_crucial "git checkout master"
      run_crucial "git merge origin/master"
      run_crucial "git checkout #{branch}"
      raise MasterNonFastForwardError if not fast_forward_merge? "master", branch

      run_crucial "git push -f origin #{branch}"

      invoke :ci

      run_crucial "git checkout master"
      run_crucial "git merge #{branch}"
      run_crucial "git push origin master"
    end

    run_crucial "cap _2.5.10_ deploy", options.verbose?

    puts green("Deploy Succeeded")

    if branch != "master"
      puts "Deleting branch: #{branch}"
      run_crucial "git push --delete origin #{branch}"
      run_crucial "git branch -d #{branch}"
    end
  end

  method_options %w( verbose -v ) => :boolean
  desc "ci", "runs ci against current HEAD"
  def ci
    ci = CI.new(project_name, current_sha)
    return unless ci.exists?
    puts "Continuous integration: starting build on #{current_branch}..."

    success = ci.run do |elapsed_time, last_time|
      if last_time
        percentage = (elapsed_time.to_f / last_time.to_f * 100).to_i
        output = "  Estimated completion: #{percentage}%"
      else
        output = "  No estimated completion time. Elapsed time: #{elapsed_time} sec"
      end
      print "\x08" * output.length
      print output
      $stdout.flush
    end

    if success
      puts
      puts "Continuous integration: success! deploying to production"
    else
      puts
      puts ci.console
      puts "Automated tests failed!"
    end
  end
end

