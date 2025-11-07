require "spec_helper"
require "bard/target"
require "bard/deploy_strategy"

describe "Dynamic DSL Methods" do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) { Bard::Target.new(:production, config) }

  before do
    # Register test strategies
    class Bard::DeployStrategy::Jets < Bard::DeployStrategy
      def deploy
        # test implementation
      end
    end

    class Bard::DeployStrategy::Docker < Bard::DeployStrategy
      def deploy
        # test implementation
      end
    end
  end

  describe "method_missing for strategies" do
    it "enables strategy when method name matches registered strategy" do
      target.jets("https://api.example.com")
      expect(target.deploy_strategy).to eq(:jets)
    end

    it "stores strategy options" do
      target.jets("https://api.example.com", run_tests: true, env: "production")
      options = target.strategy_options(:jets)
      expect(options[:run_tests]).to be true
      expect(options[:env]).to eq("production")
    end

    it "auto-configures ping URL from first argument if it's a URL" do
      target.jets("https://api.example.com")
      expect(target.ping_urls).to include("https://api.example.com")
    end

    it "works with multiple strategies" do
      target1 = Bard::Target.new(:production, config)
      target2 = Bard::Target.new(:staging, config)

      target1.jets("https://api.example.com")
      target2.docker("https://app.example.com")

      expect(target1.deploy_strategy).to eq(:jets)
      expect(target2.deploy_strategy).to eq(:docker)
    end

    it "raises NoMethodError for unknown methods" do
      expect { target.unknown_method("arg") }
        .to raise_error(NoMethodError)
    end
  end

  describe "strategy DSL integration" do
    it "allows chaining with other configuration methods" do
      target.jets("https://api.example.com", run_tests: true)
      target.ssh("deploy@example.com:22", path: "app")

      expect(target.deploy_strategy).to eq(:jets)
      expect(target.has_capability?(:ssh)).to be true
    end

    it "allows strategy configuration without ping URL" do
      target.docker(skip_build: true)
      options = target.strategy_options(:docker)
      expect(options[:skip_build]).to be true
    end
  end

  describe "#strategy_options" do
    it "returns options for the specified strategy" do
      target.jets("https://api.example.com", run_tests: true, env: "prod")
      options = target.strategy_options(:jets)
      expect(options[:run_tests]).to be true
      expect(options[:env]).to eq("prod")
    end

    it "returns empty hash if strategy not configured" do
      options = target.strategy_options(:unknown)
      expect(options).to eq({})
    end

    it "filters out URL from options" do
      target.jets("https://api.example.com", run_tests: true)
      options = target.strategy_options(:jets)
      expect(options[:run_tests]).to be true
      expect(options).not_to have_key(:url)
    end
  end

  describe "#deploy_strategy" do
    it "returns the configured strategy symbol" do
      target.jets("https://api.example.com")
      expect(target.deploy_strategy).to eq(:jets)
    end

    it "returns nil if no strategy configured" do
      expect(target.deploy_strategy).to be_nil
    end
  end

  describe "#deploy_strategy_instance" do
    it "creates an instance of the strategy class" do
      target.jets("https://api.example.com")
      instance = target.deploy_strategy_instance
      expect(instance).to be_a(Bard::DeployStrategy::Jets)
      expect(instance.target).to eq(target)
    end

    it "raises error if no strategy configured" do
      expect { target.deploy_strategy_instance }
        .to raise_error(/No deployment strategy configured/)
    end

    it "raises error if strategy class not found" do
      target.instance_variable_set(:@deploy_strategy, :unknown)
      expect { target.deploy_strategy_instance }
        .to raise_error(/Unknown deployment strategy: unknown/)
    end
  end
end
