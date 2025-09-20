require "spec_helper"
require "bard/cli"
require "bard/cli/ping"
require "thor"

class TestPingCLI < Thor
  include Bard::CLI::Ping

  attr_reader :config

  def initialize
    super
    @config = {}
  end
end

describe Bard::CLI::Ping do
  let(:server) { double("server", ping: ["https://example.com"]) }
  let(:config) { { production: server } }
  let(:cli) { TestPingCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
  end

  describe "#ping" do
    it "should have a ping command" do
      expect(cli).to respond_to(:ping)
    end

    it "should call Bard::Ping with the server" do
      expect(Bard::Ping).to receive(:call).and_return([])

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