require "spec_helper"
require "bard/plugins/provision/base"
require "bard/plugins/provision/nginx"

describe Bard::Provision::Nginx do
  let(:target) { double("target", project_name: "test_app") }
  let(:config) { double("config", project_name: "test_app", :[] => target) }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:nginx) { Bard::Provision::Nginx.new(config, ssh_url) }

  before do
    allow(nginx).to receive(:target).and_return(target)
    allow(nginx).to receive(:provision_server).and_return(provision_server)
    allow(provision_server).to receive_message_chain(:ssh_uri, :host).and_return("192.168.1.100")
    allow(nginx).to receive(:print)
    allow(nginx).to receive(:puts)
    allow(nginx).to receive(:system)
  end

  describe "#call" do
    context "when HTTP is not responding" do
      it "installs nginx" do
        allow(nginx).to receive(:http_responding?).and_return(false)
        allow(nginx).to receive(:app_configured?).and_return(true)

        expect(provision_server).to receive(:run!).with(/apt-get install -y nginx/, home: true)

        nginx.call
      end
    end

    context "when app is not configured" do
      it "creates nginx config" do
        allow(nginx).to receive(:http_responding?).and_return(true)
        allow(nginx).to receive(:app_configured?).and_return(false)

        expect(provision_server).to receive(:run!).with("bard setup")

        nginx.call
      end
    end

    context "when everything is already set up" do
      it "skips installation and configuration" do
        allow(nginx).to receive(:http_responding?).and_return(true)
        allow(nginx).to receive(:app_configured?).and_return(true)

        expect(provision_server).not_to receive(:run!)

        nginx.call
      end
    end

    it "prints status messages" do
      allow(nginx).to receive(:http_responding?).and_return(true)
      allow(nginx).to receive(:app_configured?).and_return(true)

      expect(nginx).to receive(:print).with("Nginx:")
      expect(nginx).to receive(:puts).with(" ✓")

      nginx.call
    end
  end

  describe "#http_responding?" do
    it "checks if port 80 is responding" do
      expect(nginx).to receive(:system).with("nc -zv 192.168.1.100 80 2>/dev/null")

      nginx.http_responding?
    end
  end

  describe "#app_configured?" do
    it "checks if nginx config exists for the app" do
      expect(provision_server).to receive(:run).with("[ -f /etc/nginx/sites-enabled/test_app ]", quiet: true)

      nginx.app_configured?
    end
  end
end
