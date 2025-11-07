require "spec_helper"
require "bard/deploy_strategy"

describe Bard::DeployStrategy do
  describe "auto-registration" do
    it "registers strategies via inherited hook" do
      # Define a test strategy
      class Bard::DeployStrategy::TestStrategy < Bard::DeployStrategy
      end

      expect(Bard::DeployStrategy[:test_strategy]).to eq(Bard::DeployStrategy::TestStrategy)
    end

    it "extracts strategy name from class name" do
      class Bard::DeployStrategy::MyCustomStrategy < Bard::DeployStrategy
      end

      expect(Bard::DeployStrategy[:my_custom_strategy]).to eq(Bard::DeployStrategy::MyCustomStrategy)
    end

    it "handles nested module names" do
      module CustomModule
        class Bard::DeployStrategy::NestedStrategy < Bard::DeployStrategy
        end
      end

      expect(Bard::DeployStrategy[:nested_strategy]).to eq(CustomModule::Bard::DeployStrategy::NestedStrategy)
    end

    it "allows retrieval of registered strategies" do
      class Bard::DeployStrategy::RetrievalTest < Bard::DeployStrategy
      end

      strategy_class = Bard::DeployStrategy[:retrieval_test]
      expect(strategy_class).to eq(Bard::DeployStrategy::RetrievalTest)
      expect(strategy_class.superclass).to eq(Bard::DeployStrategy)
    end
  end

  describe ".strategies" do
    it "returns a hash of all registered strategies" do
      class Bard::DeployStrategy::Strategy1 < Bard::DeployStrategy
      end
      class Bard::DeployStrategy::Strategy2 < Bard::DeployStrategy
      end

      strategies = Bard::DeployStrategy.strategies
      expect(strategies).to be_a(Hash)
      expect(strategies[:strategy1]).to eq(Bard::DeployStrategy::Strategy1)
      expect(strategies[:strategy2]).to eq(Bard::DeployStrategy::Strategy2)
    end
  end

  describe ".[]" do
    it "retrieves a strategy by symbol" do
      class Bard::DeployStrategy::LookupTest < Bard::DeployStrategy
      end

      expect(Bard::DeployStrategy[:lookup_test]).to eq(Bard::DeployStrategy::LookupTest)
    end

    it "returns nil for unknown strategies" do
      expect(Bard::DeployStrategy[:unknown_strategy]).to be_nil
    end
  end

  describe "#initialize" do
    let(:target) { double("target") }

    it "stores the target" do
      strategy = described_class.new(target)
      expect(strategy.target).to eq(target)
    end
  end

  describe "#deploy" do
    let(:target) { double("target") }
    let(:strategy) { described_class.new(target) }

    it "raises NotImplementedError" do
      expect { strategy.deploy }.to raise_error(NotImplementedError)
    end
  end

  describe "helper methods" do
    let(:target) { double("target") }
    let(:strategy) { described_class.new(target) }

    describe "#run!" do
      it "delegates to Bard::Command.run!" do
        expect(Bard::Command).to receive(:run!).with("ls -l")
        strategy.run!("ls -l")
      end
    end

    describe "#run" do
      it "delegates to Bard::Command.run" do
        expect(Bard::Command).to receive(:run).with("ls -l")
        strategy.run("ls -l")
      end
    end

    describe "#system!" do
      it "delegates to Kernel.system with error checking" do
        expect(Kernel).to receive(:system).with("ls -l").and_return(true)
        strategy.system!("ls -l")
      end

      it "raises error if command fails" do
        expect(Kernel).to receive(:system).with("false").and_return(false)
        expect { strategy.system!("false") }.to raise_error(/Command failed/)
      end
    end
  end
end
