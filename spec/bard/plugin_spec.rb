require "bard/plugin"

RSpec.describe Bard::Plugin do
  before do
    described_class.reset!
  end

  describe ".register" do
    it "registers a plugin by name" do
      described_class.register :test_plugin

      expect(described_class[:test_plugin]).to be_a(Bard::Plugin)
      expect(described_class[:test_plugin].name).to eq :test_plugin
    end

    it "accepts a block to configure the plugin" do
      described_class.register :test_plugin do
        require_file "some/file"
      end

      plugin = described_class[:test_plugin]
      expect(plugin.instance_variable_get(:@requires)).to include("some/file")
    end
  end

  describe ".all" do
    it "returns all registered plugins" do
      described_class.register :plugin1
      described_class.register :plugin2

      expect(described_class.all.map(&:name)).to contain_exactly(:plugin1, :plugin2)
    end
  end

  describe ".reset!" do
    it "clears the registry" do
      described_class.register :test_plugin

      described_class.reset!

      expect(described_class.all).to be_empty
    end
  end

  describe "#cli" do
    it "stores CLI modules to include" do
      described_class.register :test_plugin do
        cli "SomeModule", require: "some/module"
      end

      plugin = described_class[:test_plugin]
      expect(plugin.cli_modules).to include("SomeModule")
    end
  end

  describe "#target_method" do
    it "stores target methods to define" do
      block = proc { "value" }
      described_class.register :test_plugin do
        target_method :custom_method, &block
      end

      plugin = described_class[:test_plugin]
      expect(plugin.instance_variable_get(:@target_methods)).to have_key(:custom_method)
    end
  end

  describe "#config_method" do
    it "stores config methods to define" do
      block = proc { "value" }
      described_class.register :test_plugin do
        config_method :custom_method, &block
      end

      plugin = described_class[:test_plugin]
      expect(plugin.instance_variable_get(:@config_methods)).to have_key(:custom_method)
    end
  end
end
