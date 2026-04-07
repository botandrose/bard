require "spec_helper"
require "bard/cli"

describe "bard master_key" do
  let(:from_server) { double("production") }
  let(:to_server) { double("local") }
  let(:config) { { production: from_server, local: to_server } }
  let(:cli) { Bard::CLI.new }

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
      expect(Bard::Copy).to receive(:file).with("config/master.key", from: from_server, to: to_server)

      cli.master_key
    end

    it "should copy master key with custom servers" do
      staging_server = double("staging")
      allow(config).to receive(:[]).with("production").and_return(staging_server)
      allow(config).to receive(:[]).with("local").and_return(to_server)
      allow(cli).to receive(:options).and_return({ from: "production", to: "local" })
      expect(Bard::Copy).to receive(:file).with("config/master.key", from: staging_server, to: to_server)

      cli.master_key
    end
  end
end
