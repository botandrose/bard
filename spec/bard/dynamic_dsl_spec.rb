require "spec_helper"
require "bard/target"
require "bard/plugins/deploy"

describe "Deploy strategy target methods" do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) { Bard::Target.new(:production, config) }

  describe "#deploy_strategy" do
    it "returns nil if no strategy configured" do
      expect(target.deploy_strategy).to be_nil
    end

    it "returns :ssh after ssh is configured via deploy_strategy_instance" do
      target.ssh("deploy@example.com:22")
      expect(target.deploy_strategy_instance).to be_a(Bard::DeployStrategy::SSH)
    end
  end

  describe "#deploy_strategy_instance" do
    it "defaults to SSH strategy when SSH capability is present" do
      target.ssh("deploy@example.com:22")
      instance = target.deploy_strategy_instance
      expect(instance).to be_a(Bard::DeployStrategy::SSH)
      expect(instance.target).to eq(target)
    end

    it "raises error if no strategy configured and no SSH capability" do
      expect { target.deploy_strategy_instance }
        .to raise_error(/No deployment strategy configured/)
    end

    it "raises error if strategy class not found" do
      target.instance_variable_set(:@deploy_strategy, :unknown)
      expect { target.deploy_strategy_instance }
        .to raise_error(/Unknown deployment strategy: unknown/)
    end
  end

  describe "#strategy_options" do
    it "returns empty hash if strategy not configured" do
      options = target.strategy_options(:unknown)
      expect(options).to eq({})
    end
  end
end
