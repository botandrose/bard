require "spec_helper"
require "bard/plugins/provision/base"
require "bard/plugins/provision/logrotation"

describe Bard::Provision::LogRotation do
  let(:target) { double("target", project_name: "test_app") }
  let(:config) { double("config", project_name: "test_app", :[] => target) }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:logrotation) { Bard::Provision::LogRotation.new(config, ssh_url) }

  before do
    allow(logrotation).to receive(:target).and_return(target)
    allow(logrotation).to receive(:provision_server).and_return(provision_server)
    allow(logrotation).to receive(:print)
    allow(logrotation).to receive(:puts)
  end

  describe "#call" do
    it "sets up log rotation config on the target" do
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