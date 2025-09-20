require "spec_helper"
require "bard/provision"
require "bard/provision/app"

describe Bard::Provision::App do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:app) { Bard::Provision::App.new(config, ssh_url) }

  before do
    allow(app).to receive(:provision_server).and_return(provision_server)
    allow(app).to receive(:print)
    allow(app).to receive(:puts)
  end

  describe "#call" do
    it "runs bin/setup on the server" do
      expect(provision_server).to receive(:run!).with("bin/setup")

      app.call
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run!)

      expect(app).to receive(:print).with("App:")
      expect(app).to receive(:puts).with(" ✓")

      app.call
    end
  end
end