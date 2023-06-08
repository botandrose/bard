require "forwardable"

class Bard::CLI < Thor
  class CI
    def initialize project_name, branch, local: false
      @project_name = project_name
      @branch = branch
      @local = !!local
    end

    attr_reader :project_name, :branch, :runner

    def sha
      @sha ||= `git rev-parse #{branch}`.chomp
    end

    def runner
      @runner ||= choose_runner_class.new(project_name, branch, sha)
    end

    extend Forwardable
    delegate [:run, :exists?, :console, :last_response, :status] => :runner

    private

    def choose_runner_class
      if local?
        require_relative "./ci/local"
        Local
      else
        if github_actions?
          require_relative "./ci/github_actions"
          GithubActions
        else
          require_relative "./ci/jenkins"
          Jenkins
        end
      end
    end

    def local?
      @local
    end

    def github_actions?
      File.exist?(".github/workflows/ci.yml")
    end
  end
end

