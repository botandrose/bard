require "spec_helper"
require "bard/provision"
require "bard/provision/swapfile"

describe Bard::Provision::Swapfile do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:swapfile) { Bard::Provision::Swapfile.new(config, ssh_url) }

  before do
    allow(swapfile).to receive(:provision_server).and_return(provision_server)
    allow(swapfile).to receive(:print)
    allow(swapfile).to receive(:puts)
  end

  describe "#call" do
    it "sets up swapfile on the server" do
      expect(provision_server).to receive(:run!).with(/if \[ ! -f \/swapfile \]/, home: true).ordered
      expect(provision_server).to receive(:run!).with("sudo swapon --show | grep -q /swapfile", home: true).ordered

      swapfile.call
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run!)
      expect(swapfile).to receive(:print).with("Swapfile:")
      expect(swapfile).to receive(:puts).with(" ✓")

      swapfile.call
    end
  end
end