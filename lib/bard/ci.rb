require "forwardable"

module Bard
  class CI
    def initialize project_name, branch, local: false
      @project_name = project_name
      @branch = branch
      @local = !!local
    end

    extend Forwardable
    delegate [:run, :exists?, :console, :status] => :runner

    private

    def local?
      @local
    end

    def github_actions?
      File.exist?(".github/workflows/ci.yml")
    end

    def jenkins?
      !local? && !github_actions?
    end

    def runner
      @runner ||= choose_runner_class.new(@project_name, @branch, sha)
    end

    def sha
      @sha ||= `git rev-parse #{@branch}`.chomp
    end

    def choose_runner_class
      if local?
        require_relative "./ci/local"
        Local
      elsif github_actions?
        require_relative "./ci/github_actions"
        GithubActions
      elsif jenkins?
        require_relative "./ci/jenkins"
        Jenkins
      end
    end
  end
end

