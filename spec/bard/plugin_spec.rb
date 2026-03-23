require "bard/plugin"

RSpec.describe Bard::Plugin do
  before do
    described_class.reset!
  end

  describe ".commands" do
    it "auto-registers Command subclasses via inherited hook" do
      klass = Class.new(Bard::Plugin::Command)
      expect(described_class.commands).to include(klass)
    end
  end

  describe ".reset!" do
    it "clears the commands list" do
      Class.new(Bard::Plugin::Command)
      described_class.reset!
      expect(described_class.commands).to be_empty
    end
  end

  describe ".load!" do
    it "calls setup on all registered commands" do
      klass = Class.new(Bard::Plugin::Command) do
        desc "test_cmd", "a test"
        def test_cmd; end
      end

      cli = Class.new(Thor)
      described_class.load!(cli)

      expect(cli.instance_methods).to include(:test_cmd)
    end
  end
end
