require "spec_helper"
require "bard/cli"
require "bard/cli/ssh"
require "thor"

class TestSSHCLI < Thor
  include Bard::CLI::SSH

  attr_reader :config, :options

  def initialize
    super
    @config = {}
    @options = {}
  end
end

describe Bard::CLI::SSH do
  let(:server) { double("server") }
  let(:config) { { production: server } }
  let(:cli) { TestSSHCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
  end

  describe "#ssh" do
    it "should have an ssh command" do
      expect(cli).to respond_to(:ssh)
    end

    it "should execute shell on production server by default" do
      allow(cli).to receive(:options).and_return({ home: false })
      expect(server).to receive(:exec!).with("exec $SHELL -l", home: false)

      cli.ssh
    end

    it "should execute shell with home option when specified" do
      allow(cli).to receive(:options).and_return({ home: true })
      expect(server).to receive(:exec!).with("exec $SHELL -l", home: true)

      cli.ssh
    end

    it "should connect to specified server" do
      staging_server = double("staging")
      allow(config).to receive(:[]).with(:staging).and_return(staging_server)
      allow(cli).to receive(:options).and_return({ home: false })
      expect(staging_server).to receive(:exec!).with("exec $SHELL -l", home: false)

      cli.ssh(:staging)
    end
  end
end