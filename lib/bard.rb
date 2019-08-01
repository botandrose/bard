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
  desc "stage", "pushes current branch, and stages it"
  def stage
    unless File.read("Capfile").include?("role :production")
      raise Thor::Error.new("`bard stage` is disabled until a production server is defined. Until then, please use `bard deploy` to deploy to the staging server.")
    end

    branch = Git.current_branch

    run_crucial "git push -u origin #{branch}", true
    run_crucial "cap _2.5.10_ stage BRANCH=#{branch}", options.verbose?
    puts green("Stage Succeeded")

    unless system("cap _2.5.10_ ping ROLES=staging >/dev/null 2>&1")
      puts red("Staging is now down!")
    end
  end

  method_options %w( verbose -v ) => :boolean, %w( skip-ci ) => :boolean
  desc "deploy [BRANCH=HEAD]", "checks that branch is a ff with master, checks with ci, and then merges into master and deploys to production, and deletes branch."
  def deploy branch=Git.current_branch
    if branch == "master"
      run_crucial "git push origin master:master"
      invoke :ci unless options["skip-ci"]

    else
      run_crucial "git fetch origin master:master"

      if not Git.fast_forward_merge? "origin/master", branch
        puts "The master branch has advanced. Attempting rebase..."
        run_crucial "git rebase origin/master"
      end

      run_crucial "git push -f origin #{branch}:#{branch}"

      invoke :ci unless options["skip-ci"]

      run_crucial "git push origin #{branch}:master"
      run_crucial "git fetch origin master:master"
    end

    run_crucial "cap _2.5.10_ deploy", options.verbose?

    puts green("Deploy Succeeded")

    if branch != "master"
      puts "Deleting branch: #{branch}"
      run_crucial "git push --delete origin #{branch}"

      case Git.current_branch
      when branch
        run_crucial "git checkout master"
        run_crucial "git branch -d #{branch}"
      when "master"
        run_crucial "git branch -d #{branch}"
      else
        run_crucial "git branch -D #{branch}"
      end
    end

    unless system("cap _2.5.10_ ping ROLES=production >/dev/null 2>&1")
      puts red("Production is now down!")
    end
  end

  method_options %w( verbose -v ) => :boolean
  desc "ci [BRANCH=HEAD]", "runs ci against BRANCH"
  def ci branch=Git.current_branch
    ci = CI.new(project_name, `git rev-parse #{branch}`.chomp)
    if ci.exists?
      puts "Continuous integration: starting build on #{branch}..."

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
        puts "Continuous integration: success!"
        if File.exist?("coverage")
          puts "Downloading test coverage from CI..."
          run_crucial "cap _2.5.10_ download_ci_test_coverage"
        end
        puts "Deploying..."
      else
        puts
        puts ci.last_response
        puts ci.console
        puts red("Automated tests failed!")
        exit 1
      end

    else
      puts red("No CI found for #{project_name}!")
      puts "Re-run with --skip-ci to bypass CI, if you absolutely must, and know what you're doing."
      exit 1
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

  method_options %w( home ) => :boolean
  desc "ssh [TO=production]", "logs into the specified server via SSH"
  def ssh to="production"
    if to == "gubs"
      command = "exec $SHELL"
      command = "cd Sites/#{project_name} && #{command}" unless options["home"]
      command = %(ssh -t gubito@gubs.pagekite.me 'bash -l -c "cd vagrant && exec vagrant ssh -c\\"#{command}\\""')
      exec command
    else
      exec "cap _2.5.10_ ssh ROLES=#{to}#{" NOCD=1" if options["home"]}"
    end
  end

  desc "install", "copies bin/setup and bin/ci scripts into current project."
  def install
    install_files_path = File.expand_path(File.join(__dir__, "../install_files/*"))
    system "cp #{install_files_path} bin/"
  end
end

