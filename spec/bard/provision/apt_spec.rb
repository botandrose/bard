require "spec_helper"
require "bard/provision"
require "bard/provision/apt"

describe Bard::Provision::Apt do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:apt) { Bard::Provision::Apt.new(config, ssh_url) }

  before do
    allow(apt).to receive(:provision_server).and_return(provision_server)
    allow(apt).to receive(:print)
    allow(apt).to receive(:puts)
  end

  describe "#call" do
    it "updates and installs packages on the server" do
      expected_commands = [
        %(echo "\\$nrconf{restart} = \\"a\\";" | sudo tee /etc/needrestart/conf.d/90-autorestart.conf),
        "sudo apt-get update -y",
        "sudo apt-get upgrade -y",
        "sudo apt-get install -y curl"
      ].join("; ")

      expect(provision_server).to receive(:run!).with(expected_commands, home: true)

      apt.call
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run!)
      expect(apt).to receive(:print).with("Apt:")
      expect(apt).to receive(:puts).with(" ✓")

      apt.call
    end
  end
end