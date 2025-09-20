require "spec_helper"
require "bard/cli"
require "bard/cli/command"

class TestCommand < Bard::CLI::Command
  desc "test_command", "test command description"
  option :verbose, type: :boolean

  def test_command
    "executed"
  end
end

describe Bard::CLI::Command do
  let(:cli_mock) { double("cli") }
  let(:command) { TestCommand.new(cli_mock) }

  describe ".desc" do
    it "sets command and description" do
      expect(TestCommand.instance_variable_get(:@command)).to eq("test_command")
      expect(TestCommand.instance_variable_get(:@description)).to eq("test command description")
    end
  end

  describe ".option" do
    it "sets option arguments" do
      expect(TestCommand.instance_variable_get(:@option_args)).to eq([:verbose])
      expect(TestCommand.instance_variable_get(:@option_kwargs)).to eq({type: :boolean})
    end
  end

  describe ".setup" do
    let(:cli_double) { double("cli") }

    it "sets up the command on the CLI class" do
      expect(cli_double).to receive(:desc).with("test_command", "test command description")
      expect(cli_double).to receive(:option).with(:verbose, type: :boolean)
      expect(cli_double).to receive(:define_method)

      TestCommand.setup(cli_double)
    end
  end

  describe "delegation" do
    it "should delegate to the wrapped object" do
      allow(cli_mock).to receive(:some_method).and_return("delegated")
      expect(command.some_method).to eq("delegated")
    end
  end
end