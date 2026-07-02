require "spec_helper"
require "bard/cli"

describe "bard stage" do
  let(:staging_strategy) { double("staging_strategy", deploy: true) }
  let(:staging_server) { double("staging", deploy_strategy: :ssh, deploy_strategy_instance: staging_strategy) }
  let(:production_server) { double("production") }
  let(:targets) { { production: production_server, staging: staging_server } }
  let(:config) { double("config", targets: targets) }
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:run!)
    allow(cli).to receive(:ping)
    allow(cli).to receive(:green).and_return("")
    allow(cli).to receive(:red).and_return("")
    allow(cli).to receive(:yellow) { |s| s }
    allow(Bard::Git).to receive(:current_branch).and_return("main")
    allow(config).to receive(:[]).with(:staging).and_return(staging_server)
    allow(config).to receive(:[]).with(:production).and_return(production_server)
    allow(cli).to receive(:project_name).and_return("acme")
    allow(cli).to receive(:staging_provisioned?).and_return(true)
  end

  describe "#stage" do
    it "should have a stage command" do
      expect(cli).to respond_to(:stage)
    end

    context "when the staging site has been reaped" do
      before do
        allow(cli).to receive(:staging_provisioned?).and_return(false)
        allow(cli).to receive(:invoke)
        allow($stdin).to receive(:tty?).and_return(false)
      end

      it "provisions from scratch by cloning and checking out the branch" do
        expect(staging_strategy).to receive(:deploy).with(clone: "acme", branch: "main")
        cli.stage
      end

      it "restores data from production by default (Enter/no decline)" do
        allow(staging_strategy).to receive(:deploy)
        allow($stdin).to receive(:tty?).and_return(true)
        allow(cli).to receive(:no?).and_return(false)
        expect(cli).to receive(:invoke).with(:data, [], from: "production", to: "staging")
        cli.stage
      end

      it "skips the restore when the user declines" do
        allow(staging_strategy).to receive(:deploy)
        allow($stdin).to receive(:tty?).and_return(true)
        allow(cli).to receive(:no?).and_return(true)
        expect(cli).not_to receive(:invoke)
        cli.stage
      end

      it "prints restore instructions when non-interactive" do
        allow(staging_strategy).to receive(:deploy)
        expect(cli).to receive(:puts).with(/bard data --from production --to staging/)
        cli.stage
      end
    end

    context "when the staging site already exists" do
      it "does not prompt to restore data" do
        allow($stdin).to receive(:tty?).and_return(true)
        expect(cli).not_to receive(:invoke)
        cli.stage
      end
    end

    context "when production server is defined" do
      it "pushes branch and stages it" do
        expect(cli).to receive(:run!).with("git push -u origin main", verbose: true)
        expect(staging_strategy).to receive(:deploy)
        expect(cli).to receive(:ping).with(:staging)

        cli.stage
      end

      it "accepts custom branch" do
        expect(cli).to receive(:run!).with("git push -u origin develop", verbose: true)
        expect(staging_strategy).to receive(:deploy)

        cli.stage("develop")
      end
    end

    context "when staging target has a deploy strategy" do
      let(:strategy_instance) { double("strategy") }
      let(:staging_server) { double("staging", deploy_strategy: :fake, deploy_strategy_instance: strategy_instance) }

      it "uses the deploy strategy" do
        expect(cli).to receive(:run!).with("git push -u origin main", verbose: true)
        expect(strategy_instance).to receive(:deploy)
        expect(cli).to receive(:ping).with(:staging)

        cli.stage
      end
    end

    context "when production target is equivalent to staging" do
      before do
        allow(config).to receive(:[]).with(:production).and_return(staging_server)
      end

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
