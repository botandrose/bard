require "spec_helper"
require "bard/provision"
require "bard/provision/logrotation"

describe Bard::Provision::LogRotation do
  let(:server) { double("server", project_name: "test_app") }
  let(:config) { { production: server } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:logrotation) { Bard::Provision::LogRotation.new(config, ssh_url) }

  before do
    allow(logrotation).to receive(:server).and_return(server)
    allow(logrotation).to receive(:provision_server).and_return(provision_server)
    allow(logrotation).to receive(:print)
    allow(logrotation).to receive(:puts)
  end

  describe "#call" do
    it "sets up log rotation config on the server" do
      expect(provision_server).to receive(:run!).with(/file=\/etc\/logrotate\.d\/test_app/, quiet: true)

      logrotation.call
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run!)
      expect(logrotation).to receive(:print).with("Log Rotation:")
      expect(logrotation).to receive(:puts).with(" ✓")

      logrotation.call
    end
  end
end