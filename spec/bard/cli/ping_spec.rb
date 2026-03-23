require "spec_helper"
require "bard/cli"
require "thor"

describe "bard ping" do
  let(:server) { double("server", ping: ["https://example.com"]) }
  let(:config) { double("config", targets: { production: server }) }
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(config).to receive(:[]).with(:production).and_return(server)
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
  end

  describe "#ping" do
    it "should call Bard::Ping with the server" do
      expect(Bard::Ping).to receive(:call).with(server).and_return([])

      cli.ping
    end

    it "should print down URLs when they exist" do
      down_urls = ["https://down.example.com"]
      allow(Bard::Ping).to receive(:call).and_return(down_urls)
      expect(cli).to receive(:puts).with("https://down.example.com is down!")

      cli.ping
    end
  end
end
