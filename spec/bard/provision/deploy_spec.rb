require "spec_helper"
require "bard/provision"
require "bard/provision/deploy"

describe Bard::Provision::Deploy do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:deploy) { Bard::Provision::Deploy.new(config, ssh_url) }

  before do
    allow(deploy).to receive(:provision_server).and_return(provision_server)
    allow(deploy).to receive(:print)
    allow(deploy).to receive(:puts)
  end

  describe "#call" do
    it "runs bin/setup on the server" do
      expect(provision_server).to receive(:run!).with("bin/setup")

      deploy.call
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run!)

      expect(deploy).to receive(:print).with("Deploy:")
      expect(deploy).to receive(:puts).with(" ✓")

      deploy.call
    end
  end
end