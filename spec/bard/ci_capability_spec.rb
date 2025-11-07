require "spec_helper"
require "bard/config"
require "bard/ci"

describe "CI Capability" do
  let(:config) { Bard::Config.new(project_name: "testapp") }

  describe "auto-detection" do
    it "detects GitHub Actions if .github/workflows/ci.yml exists" do
      allow(File).to receive(:exist?)
        .with(".github/workflows/ci.yml")
        .and_return(true)

      ci = Bard::CI.auto_detect(config)
      expect(ci).to be_a(Bard::CI::GithubActions)
    end

    it "defaults to Jenkins if no GitHub Actions config" do
      allow(File).to receive(:exist?)
        .with(".github/workflows/ci.yml")
        .and_return(false)

      ci = Bard::CI.auto_detect(config)
      expect(ci).to be_a(Bard::CI::Jenkins)
    end
  end

  describe "manual configuration" do
    it "allows forcing GitHub Actions" do
      config.ci(:github_actions)
      expect(config.ci_system).to eq(:github_actions)
    end

    it "allows forcing Jenkins" do
      config.ci(:jenkins)
      expect(config.ci_system).to eq(:jenkins)
    end

    it "allows forcing local CI" do
      config.ci(:local)
      expect(config.ci_system).to eq(:local)
    end

    it "allows disabling CI" do
      config.ci(false)
      expect(config.ci_system).to eq(false)
    end
  end

  describe "CI instance creation" do
    it "creates GitHub Actions instance when configured" do
      config.ci(:github_actions)
      ci = config.ci_instance("branch")
      expect(ci).to be_a(Bard::CI::GithubActions)
    end

    it "creates Jenkins instance when configured" do
      config.ci(:jenkins)
      ci = config.ci_instance("branch")
      expect(ci).to be_a(Bard::CI::Jenkins)
    end

    it "creates Local instance when configured" do
      config.ci(:local)
      ci = config.ci_instance("branch")
      expect(ci).to be_a(Bard::CI::Local)
    end

    it "returns nil when CI is disabled" do
      config.ci(false)
      ci = config.ci_instance("branch")
      expect(ci).to be_nil
    end

    it "auto-detects when not explicitly configured" do
      allow(File).to receive(:exist?)
        .with(".github/workflows/ci.yml")
        .and_return(true)

      ci = config.ci_instance("branch")
      expect(ci).to be_a(Bard::CI::GithubActions)
    end
  end

  describe "deployment integration" do
    it "runs CI before deployment by default" do
      config.ci(:local)

      deploy = Bard::CLI::Deploy.new
      expect(deploy).to receive(:run_ci).with("master")

      deploy.deploy("production", branch: "master")
    end

    it "skips CI when --skip-ci flag is used" do
      config.ci(:local)

      deploy = Bard::CLI::Deploy.new(skip_ci: true)
      expect(deploy).not_to receive(:run_ci)

      deploy.deploy("production", branch: "master")
    end

    it "skips CI when CI is disabled" do
      config.ci(false)

      deploy = Bard::CLI::Deploy.new
      expect(deploy).not_to receive(:run_ci)

      deploy.deploy("production", branch: "master")
    end
  end

  describe "CI commands" do
    describe "bard ci" do
      it "runs CI for current branch" do
        config.ci(:local)
        allow(Bard::Git).to receive(:current_branch).and_return("feature")

        ci = config.ci_instance("feature")
        expect(ci).to receive(:run)

        Bard::CLI::CI.new.run("feature")
      end

      it "fails with clear message if CI is disabled" do
        config.ci(false)

        expect { Bard::CLI::CI.new.run("master") }
          .to raise_error(/CI is disabled for this project/)
      end
    end

    describe "bard ci --local-ci" do
      it "forces local CI execution" do
        config.ci(:jenkins)

        cli = Bard::CLI::CI.new(local_ci: true)
        ci = cli.get_ci_instance("master")

        expect(ci).to be_a(Bard::CI::Local)
      end
    end

    describe "bard ci --status" do
      it "checks CI status" do
        config.ci(:github_actions)

        ci = config.ci_instance("master")
        expect(ci).to receive(:status)

        Bard::CLI::CI.new(status: true).run("master")
      end
    end

    describe "bard ci --resume" do
      it "resumes existing CI build" do
        config.ci(:jenkins)

        ci = config.ci_instance("master")
        expect(ci).to receive(:resume)

        Bard::CLI::CI.new(resume: true).run("master")
      end
    end
  end

  describe "CI systems" do
    describe "Local CI" do
      let(:local_ci) { Bard::CI::Local.new("testapp", "master") }

      it "runs tests locally" do
        expect(local_ci).to receive(:system!)
          .with(/bundle exec rspec/)

        local_ci.run
      end

      it "supports custom test commands" do
        allow(File).to receive(:exist?)
          .with("bin/test")
          .and_return(true)

        expect(local_ci).to receive(:system!)
          .with(/bin\/test/)

        local_ci.run
      end
    end

    describe "Jenkins CI" do
      let(:jenkins_ci) { Bard::CI::Jenkins.new("testapp", "master") }

      it "triggers Jenkins build" do
        expect(jenkins_ci).to receive(:trigger_build)
        expect(jenkins_ci).to receive(:wait_for_build)

        jenkins_ci.run
      end

      it "checks build status" do
        expect(jenkins_ci).to receive(:get_build_status)

        jenkins_ci.status
      end
    end

    describe "GitHub Actions CI" do
      let(:gh_actions_ci) { Bard::CI::GithubActions.new("testapp", "master") }

      it "triggers GitHub Actions workflow" do
        expect(gh_actions_ci).to receive(:trigger_workflow)
        expect(gh_actions_ci).to receive(:wait_for_workflow)

        gh_actions_ci.run
      end

      it "checks workflow status" do
        expect(gh_actions_ci).to receive(:get_workflow_status)

        gh_actions_ci.status
      end
    end
  end
end
