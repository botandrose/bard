require "spec_helper"
require "bard/plugins/deploy/strategy"
require "bard/plugins/deploy/ssh_strategy"

describe Bard::DeployStrategy::SSH do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) do
    t = Bard::Target.new(:production, config)
    t.ssh("deploy@example.com:22", path: "/app")
    t
  end
  let(:strategy) { described_class.new(target) }

  describe "#deploy" do
    it "requires SSH capability" do
      target_without_ssh = Bard::Target.new(:local, config)
      strategy_without_ssh = described_class.new(target_without_ssh)

      expect { strategy_without_ssh.deploy }
        .to raise_error(/SSH not configured/)
    end

    it "runs git pull on remote server" do
      expect(target).to receive(:run!)
        .with(/git pull origin master/)

      allow(target).to receive(:run!).with(/bin\/setup/)

      strategy.deploy
    end

    it "runs bin/setup on remote server" do
      allow(target).to receive(:run!).with(/git pull/)

      expect(target).to receive(:run!)
        .with(/bin\/setup/)

      strategy.deploy
    end

    it "uses configured branch if specified" do
      target.instance_variable_set(:@branch, "main")

      expect(target).to receive(:run!)
        .with(/git pull origin main/)

      allow(target).to receive(:run!).with(/bin\/setup/)

      strategy.deploy
    end
  end

  describe "auto-registration" do
    it "registers as :ssh strategy" do
      expect(Bard::DeployStrategy[:ssh]).to eq(described_class)
    end
  end

  describe "integration with target" do
    it "is the default strategy when SSH is configured" do
      require "bard/plugins/deploy"
      new_target = Bard::Target.new(:staging, config)
      new_target.ssh("deploy@staging.example.com:22")

      expect(new_target.deploy_strategy_instance).to be_a(described_class)
    end
  end
end
