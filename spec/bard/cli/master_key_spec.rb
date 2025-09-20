require "spec_helper"
require "bard/cli"
require "bard/cli/master_key"
require "thor"

class TestMasterKeyCLI < Thor
  include Bard::CLI::MasterKey

  attr_reader :config, :options

  def initialize
    super
    @config = {}
    @options = {}
  end
end

describe Bard::CLI::MasterKey do
  let(:from_server) { double("production") }
  let(:to_server) { double("local") }
  let(:config) { { production: from_server, local: to_server } }
  let(:cli) { TestMasterKeyCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
  end

  describe "#master_key" do
    it "should have a master_key command" do
      expect(cli).to respond_to(:master_key)
    end

    it "should copy master key from production to local by default" do
      allow(config).to receive(:[]).with("production").and_return(from_server)
      allow(config).to receive(:[]).with("local").and_return(to_server)
      allow(cli).to receive(:options).and_return({ from: "production", to: "local" })
      expect(from_server).to receive(:copy_file).with("config/master.key", to: to_server)

      cli.master_key
    end

    it "should copy master key with custom servers" do
      staging_server = double("staging")
      allow(config).to receive(:[]).with("production").and_return(staging_server)
      allow(config).to receive(:[]).with("local").and_return(to_server)
      allow(cli).to receive(:options).and_return({ from: "production", to: "local" })
      expect(staging_server).to receive(:copy_file).with("config/master.key", to: to_server)

      cli.master_key
    end
  end
end