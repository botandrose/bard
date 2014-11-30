$:.unshift File.expand_path(File.dirname(__FILE__))

module Bard; end

require "bard/base"
require "bard/git"
require "bard/ci"

class Bard::CLI < Thor
  desc "data [FROM=production, TO=local]", "copy database and assets from FROM to TO"
  def data(from = "production", to = "local")
    exec "cap _2.5.10_ data:pull ROLES=#{from}" if to == "local"
    exec "cap _2.5.10_ data:push ROLES=#{to}" if from == "local"
  end

  method_options %w( verbose -v ) => :boolean
  desc "pull", "pull changes to your local machine"
  def pull
    branch = Git.current_branch

    run_crucial "git pull --rebase origin #{branch}", options.verbose?
    run_crucial "bundle && bundle exec rake bootstrap", options.verbose?
  end

  method_options %w( verbose -v ) => :boolean
  desc "stage", "pushes current branch, and stages it"
  def stage
    branch = Git.current_branch

    run_crucial "git push -u origin #{branch}", true
    run_crucial "cap _2.5.10_ stage BRANCH=#{branch}", options.verbose?

    puts green("Stage Succeeded")
  end

  method_options %w( verbose -v ) => :boolean
  desc "deploy", "checks that branch is a ff with master, checks with ci, and then merges into master and deploys to production, and deletes branch."
  def deploy
    branch = Git.current_branch

    run_crucial "git fetch origin master:master"

    if branch == "master"
      run_crucial "git push origin master:master"
      invoke :ci

    else
      if not Git.fast_forward_merge? "master", branch
        raise "The master branch has advanced since last deploy, probably due to a bugfix.\n  Rebase your branch on top of it, and check for breakage."
      end

      run_crucial "git push -f origin #{branch}:#{branch}"

      invoke :ci

      run_crucial "git push origin #{branch}:master"
      run_crucial "git fetch origin master:master"
    end

    run_crucial "cap _2.5.10_ deploy", options.verbose?

    puts green("Deploy Succeeded")

    if branch != "master"
      puts "Deleting branch: #{branch}"
      run_crucial "git checkout master" if current_branch == branch
      run_crucial "git push --delete origin #{branch}"
      run_crucial "git branch -d #{branch}"
    end
  end

  method_options %w( verbose -v ) => :boolean
  desc "ci", "runs ci against current HEAD"
  def ci
    ci = CI.new(project_name, Git.current_sha)
    return unless ci.exists?
    puts "Continuous integration: starting build on #{Git.current_branch}..."

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

  desc "hurt", "reruns a command until it fails"
  def hurt *args
    1.upto(Float::INFINITY) do |count|
      puts "Running attempt #{count}"
      system *args
      unless $?.success?
        puts "Ran #{count-1} times before failing"
        break
      end
    end
  end
end

