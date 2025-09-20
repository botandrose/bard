require "spec_helper"
require "bard/cli"
require "bard/cli/open"
require "thor"

class TestOpenCLI < Thor
  include Bard::CLI::Open

  attr_reader :config

  def initialize
    super
    @config = {}
  end

  def project_name
    "test_project"
  end
end

describe Bard::CLI::Open do
  let(:server) { double("server", ping: ["https://example.com"]) }
  let(:config) { { production: server } }
  let(:cli) { TestOpenCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:exec)
  end

  describe "#open" do
    it "should have an open command" do
      expect(cli).to respond_to(:open)
    end

    it "should open production server URL by default" do
      expect(cli).to receive(:exec).with("xdg-open https://example.com")

      cli.open
    end

    it "should open specified server URL" do
      staging_server = double("staging", ping: ["https://staging.example.com"])
      allow(config).to receive(:[]).with(:staging).and_return(staging_server)

      expect(cli).to receive(:exec).with("xdg-open https://staging.example.com")

      cli.open(:staging)
    end

    it "should open CI URL when server is ci" do
      expect(cli).to receive(:exec).with("xdg-open https://github.com/botandrosedesign/test_project/actions/workflows/ci.yml")

      cli.open(:ci)
    end
  end

  describe "#open_url" do
    it "returns CI URL for ci server" do
      expect(cli.send(:open_url, :ci)).to eq("https://github.com/botandrosedesign/test_project/actions/workflows/ci.yml")
    end

    it "returns server ping URL for other servers" do
      expect(cli.send(:open_url, :production)).to eq("https://example.com")
    end
  end
end