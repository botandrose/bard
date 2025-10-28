require "spec_helper"
require "bard/cli"
require "bard/cli/ci"
require "thor"

class TestCICLI < Thor
  include Bard::CLI::CI

  attr_reader :options

  def initialize
    super
    @options = {}
  end

  def project_name
    "test_project"
  end
end

describe Bard::CLI::CI do
  let(:cli) { TestCICLI.new }
  let(:ci_runner) { double("ci_runner") }

  before do
    allow(cli).to receive(:puts)
    allow(cli).to receive(:print)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:red).and_return("")
    allow($stdout).to receive(:flush)
    allow(Bard::Git).to receive(:current_branch).and_return("feature-branch")
    allow(Bard::CI).to receive(:new).and_return(ci_runner)
  end

  describe "#ci" do
    it "should have a ci command" do
      expect(cli).to respond_to(:ci)
    end

    context "when CI exists and status option is set" do
      it "prints CI status and returns early" do
        allow(cli).to receive(:options).and_return({ "status" => true })
        allow(ci_runner).to receive(:exists?).and_return(true)
        allow(ci_runner).to receive(:status).and_return("Build #123: SUCCESS")

        expect(cli).to receive(:puts).with("Build #123: SUCCESS")
        expect(ci_runner).not_to receive(:run)

        cli.ci
      end
    end

    context "when CI exists and running normally" do
      before do
        allow(cli).to receive(:options).and_return({})
        allow(ci_runner).to receive(:exists?).and_return(true)
      end

      it "starts CI build and handles success" do
        allow(ci_runner).to receive(:run).and_yield(30, 60).and_return(true)

        expect(cli).to receive(:puts).with("Continuous integration: starting build on feature-branch...")
        expect(cli).to receive(:puts).with("Continuous integration: success!")

        cli.ci
      end

      it "handles CI failure" do
        allow(ci_runner).to receive(:run).and_yield(30, 60).and_return(false)
        allow(ci_runner).to receive(:console).and_return("Test failed: spec/model_spec.rb")

        expect(cli).to receive(:puts).with("Continuous integration: starting build on feature-branch...")
        expect(cli).to receive(:puts).with("Test failed: spec/model_spec.rb")
        expect(cli).to receive(:puts) # The puts with newline
        expect(cli).to receive(:puts) # The "Automated tests failed!" message
        expect(cli).to receive(:exit).with(1)

        cli.ci
      end

      it "displays progress with estimated completion time" do
        allow(ci_runner).to receive(:run).and_yield(30, 60).and_return(true)

        expect(cli).to receive(:print).with("\x08" * "  Estimated completion: 50%".length)
        expect(cli).to receive(:print).with("  Estimated completion: 50%")

        cli.ci
      end

      it "displays progress without estimated completion time" do
        allow(ci_runner).to receive(:run).and_yield(45, nil).and_return(true)

        expect(cli).to receive(:print).with("\x08" * "  No estimated completion time. Elapsed time: 45 sec".length)
        expect(cli).to receive(:print).with("  No estimated completion time. Elapsed time: 45 sec")

        cli.ci
      end
    end

    context "when CI doesn't exist" do
      it "shows error message and exits" do
        allow(cli).to receive(:options).and_return({})
        allow(ci_runner).to receive(:exists?).and_return(false)

        expect(cli).to receive(:puts) # "No CI found for test_project!"
        expect(cli).to receive(:puts) # "Re-run with --skip-ci to bypass CI..."
        expect(cli).to receive(:exit).with(1)

        cli.ci
      end
    end

    context "with custom branch" do
      it "uses the specified branch" do
        allow(cli).to receive(:options).and_return({})
        allow(ci_runner).to receive(:exists?).and_return(true)
        allow(ci_runner).to receive(:run).and_return(true)

        expect(Bard::CI).to receive(:new).with("test_project", "develop", local: nil)
        expect(cli).to receive(:puts).with("Continuous integration: starting build on develop...")

        cli.ci("develop")
      end
    end

    context "with local-ci option" do
      it "passes local option to CI runner" do
        allow(cli).to receive(:options).and_return({ "local-ci" => true })
        allow(ci_runner).to receive(:exists?).and_return(true)
        allow(ci_runner).to receive(:run).and_return(true)

        expect(Bard::CI).to receive(:new).with("test_project", "feature-branch", local: true)

        cli.ci
      end
    end

    context "with resume option" do
      it "calls resume instead of run" do
        allow(cli).to receive(:options).and_return({ "resume" => true })
        allow(ci_runner).to receive(:exists?).and_return(true)
        allow(ci_runner).to receive(:resume).and_yield(30, 60).and_return(true)

        expect(cli).to receive(:puts).with("Continuous integration: resuming build...")
        expect(cli).to receive(:puts).with("Continuous integration: success!")
        expect(ci_runner).not_to receive(:run)

        cli.ci
      end

      it "displays progress when resuming" do
        allow(cli).to receive(:options).and_return({ "resume" => true })
        allow(ci_runner).to receive(:exists?).and_return(true)
        allow(ci_runner).to receive(:resume).and_yield(30, 60).and_return(true)

        expect(cli).to receive(:print).with("\x08" * "  Estimated completion: 50%".length)
        expect(cli).to receive(:print).with("  Estimated completion: 50%")

        cli.ci
      end
    end
  end
end
