$:.unshift File.expand_path(File.dirname(__FILE__))

module Bard; end

require "bard/base"
require "bard/error"
require "bard/git"

class Bard::CLI < Thor
  include Bard::CLI::Git

  desc "data [FROM=production, TO=local]", "copy database and assets from FROM to TO"
  def data(from = "production", to = "local")
    if to == "local"
      if from == "production" and heroku?
        exec "heroku db:pull --confirm #{project_name}"
      else
        exec "cap _2.5.10_ data:pull ROLES=#{from}"
      end

    else
      if from == "local"
        exec "cap _2.5.10_ data:push ROLES=#{to}"
      end
    end
  end

  method_options %w( verbose -v ) => :boolean
  desc "pull", "pull changes to your local machine"
  def pull
    run_crucial "git pull --rebase origin #{current_branch}", options.verbose?
    run_crucial "bundle && bundle exec rake bootstrap", options.verbose?
  end

  method_options %w( verbose -v ) => :boolean
  desc "push", "push local changes out to the remote"
  def push
    run_crucial "git push -u origin #{current_branch}", true
  end

  method_options %w( verbose -v ) => :boolean
  desc "stage", "pushes current branch, and stages it"
  def stage
    invoke :push

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

      invoke :ci, current_sha

      run_crucial "git checkout master"
      run_crucial "git merge #{branch}"
      run_crucial "git push origin master"
    end

    if heroku?
      run_crucial "git push production master", options.verbose?
      run_crucial "heroku run rake bootstrap:production:post", options.verbose?
    else
      run_crucial "cap _2.5.10_ deploy", options.verbose?
    end

    puts green("Deploy Succeeded")

    if branch != "master"
      puts "Deleting branch: #{branch}"
      run_crucial "git push --delete origin #{branch}"
      run_crucial "git branch -d #{branch}"
    end
  end

  method_options %w( verbose -v ) => :boolean
  desc "ci", "runs ci against current HEAD"
  def ci sha=current_sha
    return unless has_ci?

    puts "Continuous integration: starting build on #{sha}..."
    last_build_number = get_last_build_number
    last_time_elapsed = get_last_time_elapsed
    start_ci sha
    sleep(2) while last_build_number == get_last_build_number

    start_time = Time.new.to_i
    while (response = `curl -s #{ci_host}/lastBuild/api/xml?token=botandrose`).include? "<building>true</building>"
      elapsed_time = Time.new.to_i - start_time
      if last_time_elapsed
        percentage = (elapsed_time.to_f / last_time_elapsed.to_f * 100).to_i
        output = "  Estimated completion: #{percentage}%"
      else
        output = "  No estimated completion time. Elapsed time: #{elapsed_time} sec"
      end
      print "\x08" * output.length
      print output
      $stdout.flush
      sleep(2)
    end
    puts

    case response
      when /<result>FAILURE<\/result>/ then 
        puts
        puts `curl -s #{ci_host}/lastBuild/console?token=botandrose`.match(/<pre>(.+)<\/pre>/m)[1]
        puts
        raise TestsFailedError, "#{ci_host}/#{get_last_build_number}/console"

      when /<result>ABORTED<\/result>/ then 
        raise TestsAbortedError, "#{ci_host}/#{get_last_build_number}/console"

      when /<result>SUCCESS<\/result>/ then
        puts "Continuous integration: success! deploying to production"

      else raise "Unknown response from CI server: #{response}"
    end
  end

  private

  def heroku?
    `git remote -v`.include? "production\tgit@heroku.com:"
  end

  def ci_host
    "http://botandrose:thecakeisalie!@ci.botandrose.com/job/#{project_name}"
  end

  def has_ci?
    `curl -s -I #{ci_host}/?token=botandrose` =~ /\b200 OK\b/
  end

  def start_ci sha=nil
    if sha
      command = "curl -s -I -X POST '#{ci_host}/buildWithParameters?token=botandrose&GIT_REF=#{sha}'"
    else
      command = "curl -s -I -X POST '#{ci_host}/build?token=botandrose'"
    end
    puts command if options.verbose?
    `#{command}`
  end

  def get_last_build_number
    response = `curl -s #{ci_host}/lastBuild/api/xml?token=botandrose`
    response.match(/<number>(\d+)<\/number>/)
    $1 ? $1.to_i : nil
  end

  def get_last_time_elapsed
    response = `curl -s #{ci_host}/lastStableBuild/api/xml?token=botandrose`
    response.match(/<duration>(\d+)<\/duration>/)
    $1 ? $1.to_i / 1000 : nil
  end
end

