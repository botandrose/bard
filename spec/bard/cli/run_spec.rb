require "spec_helper"
require "bard/cli"
require "bard/cli/run"
require "thor"

class TestRunCLI < Thor
  include Bard::CLI::Run

  attr_reader :config

  def initialize
    super
    @config = {}
  end
end

describe Bard::CLI::Run do
  let(:server) { double("server") }
  let(:config) { { production: server } }
  let(:cli) { TestRunCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:red).and_return("")
    allow(cli).to receive(:yellow).and_return("")
  end

  describe "#run" do
    it "should have a run command" do
      expect(cli).to respond_to(:run)
    end

    it "should run command on production server" do
      expect(server).to receive(:run!).with("ls -la", verbose: true)

      cli.run("ls", "-la")
    end

    it "should handle command errors" do
      error = Bard::Command::Error.new("Command failed")
      allow(server).to receive(:run!).and_raise(error)

      expect(cli).to receive(:puts).with(/Running command failed/)
      expect(cli).to receive(:exit).with(1)

      cli.run("failing-command")
    end
  end
end