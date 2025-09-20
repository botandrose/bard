require "spec_helper"
require "bard/cli"
require "bard/cli/stage"
require "thor"

class TestStageCLI < Thor
  include Bard::CLI::Stage

  attr_reader :config

  def initialize
    super
    @config = nil
  end
end

describe Bard::CLI::Stage do
  let(:staging_server) { double("staging") }
  let(:servers) { { production: double("production"), staging: staging_server } }
  let(:config) { double("config", servers: servers) }
  let(:cli) { TestStageCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:run!)
    allow(cli).to receive(:ping)
    allow(cli).to receive(:green).and_return("")
    allow(cli).to receive(:red).and_return("")
    allow(cli).to receive(:yellow).and_return("")
    allow(Bard::Git).to receive(:current_branch).and_return("main")
    allow(config).to receive(:[]).with(:staging).and_return(staging_server)
  end

  describe "#stage" do
    it "should have a stage command" do
      expect(cli).to respond_to(:stage)
    end

    context "when production server is defined" do
      it "pushes branch and stages it" do
        expect(cli).to receive(:run!).with("git push -u origin main", verbose: true)
        expect(staging_server).to receive(:run!).with("git fetch && git checkout -f origin/main && bin/setup")
        expect(cli).to receive(:ping).with(:staging)

        cli.stage
      end

      it "accepts custom branch" do
        expect(cli).to receive(:run!).with("git push -u origin develop", verbose: true)
        expect(staging_server).to receive(:run!).with("git fetch && git checkout -f origin/develop && bin/setup")

        cli.stage("develop")
      end
    end

    context "when production server is not defined" do
      let(:servers) { { staging: staging_server } }

      it "raises an error" do
        expect { cli.stage }.to raise_error(Thor::Error, /bard stage.*is disabled/)
      end
    end

    context "when command fails" do
      it "handles errors gracefully" do
        allow(cli).to receive(:run!).and_raise(Bard::Command::Error.new("Git push failed"))

        expect(cli).to receive(:puts).with(/Running command failed/)
        expect(cli).to receive(:exit).with(1)

        cli.stage
      end
    end
  end
end