require "spec_helper"
require "bard/cli"
require "bard/cli/setup"
require "thor"

class TestSetupCLI < Thor
  include Bard::CLI::Setup

  attr_reader :config

  def initialize
    super
    @config = {}
  end

  def project_name
    "test_project"
  end
end

describe Bard::CLI::Setup do
  let(:cli) { TestSetupCLI.new }

  before do
    allow(Dir).to receive(:pwd).and_return("/home/user/project")
    allow(File).to receive(:exist?).and_return(false)
    allow(cli).to receive(:system)
  end

  describe "#setup" do
    it "should have a setup command" do
      expect(cli).to respond_to(:setup)
    end

    it "should create nginx common config" do
      expect(cli).to receive(:system).with(/sudo tee \/etc\/nginx\/snippets\/common\.conf/)
      expect(cli).to receive(:system).with(/sudo tee \/etc\/nginx\/sites-available\/test_project/)
      expect(cli).to receive(:system).with(/sudo ln -sf/)
      expect(cli).to receive(:system).with("sudo service nginx restart")

      cli.setup
    end
  end

  describe "#nginx_server_name" do
    let(:production_server) { double("production", ping: ["https://example.com"]) }

    before do
      allow(cli).to receive(:config).and_return({ production: production_server })
    end

    context "when RAILS_ENV is production" do
      before { allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("production") }

      it "returns production server names with wildcard" do
        expect(cli.send(:nginx_server_name)).to eq("*.example.com _")
      end
    end

    context "when RAILS_ENV is staging" do
      before { allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("staging") }

      it "returns staging server name" do
        expect(cli.send(:nginx_server_name)).to eq("test_project.botandrose.com")
      end
    end

    context "when RAILS_ENV is development" do
      before { allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("development") }

      it "returns localhost server name" do
        expect(cli.send(:nginx_server_name)).to eq("test_project.localhost")
      end
    end
  end
end