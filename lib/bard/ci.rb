require "forwardable"
require "bard/ci/runner"

module Bard
  class CI
    def initialize(project_name, branch, runner_name: nil)
      @project_name = project_name
      @branch = branch
      @runner_name = runner_name
    end

    extend Forwardable
    delegate [:run, :resume, :exists?, :console, :status] => :runner

    private

    def runner
      @runner ||= choose_runner_class.new(@project_name, @branch, sha)
    end

    def sha
      @sha ||= `git rev-parse #{@branch}`.chomp
    end

    def choose_runner_class
      if @runner_name
        runner_class = Runner[@runner_name]
        raise "Unknown CI runner: #{@runner_name}" unless runner_class
        runner_class
      else
        runner_class = Runner.default
        raise "No CI runner available" unless runner_class
        runner_class
      end
    end
  end
end

