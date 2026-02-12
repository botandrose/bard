require "spec_helper"
require "bard/provision"
require "bard/provision/passenger"

describe Bard::Provision::Passenger do
  let(:server) { double("server", project_name: "test_app") }
  let(:config) { double("config", project_name: "test_app", :[] => server) }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:passenger) { Bard::Provision::Passenger.new(config, ssh_url) }

  before do
    allow(passenger).to receive(:server).and_return(server)
    allow(passenger).to receive(:provision_server).and_return(provision_server)
    allow(provision_server).to receive_message_chain(:ssh_uri, :host).and_return("192.168.1.100")
    allow(passenger).to receive(:print)
    allow(passenger).to receive(:puts)
    allow(passenger).to receive(:system)
  end

  describe "#call" do
    context "when HTTP is not responding" do
      it "installs nginx and passenger" do
        allow(passenger).to receive(:http_responding?).and_return(false)
        allow(passenger).to receive(:app_configured?).and_return(true)

        expect(provision_server).to receive(:run!).with(/grep -qxF.*RAILS_ENV/, home: true)

        passenger.call
      end
    end

    context "when app is not configured" do
      it "creates nginx config" do
        allow(passenger).to receive(:http_responding?).and_return(true)
        allow(passenger).to receive(:app_configured?).and_return(false)

        expect(provision_server).to receive(:run!).with("bard setup")

        passenger.call
      end
    end

    context "when everything is already set up" do
      it "skips installation and configuration" do
        allow(passenger).to receive(:http_responding?).and_return(true)
        allow(passenger).to receive(:app_configured?).and_return(true)

        expect(provision_server).not_to receive(:run!)

        passenger.call
      end
    end

    it "prints status messages" do
      allow(passenger).to receive(:http_responding?).and_return(true)
      allow(passenger).to receive(:app_configured?).and_return(true)

      expect(passenger).to receive(:print).with("Passenger:")
      expect(passenger).to receive(:puts).with(" ✓")

      passenger.call
    end
  end

  describe "#http_responding?" do
    it "checks if port 80 is responding" do
      expect(passenger).to receive(:system).with("nc -zv 192.168.1.100 80 2>/dev/null")

      passenger.http_responding?
    end
  end

  describe "#app_configured?" do
    it "checks if nginx config exists for the app" do
      expect(provision_server).to receive(:run).with("[ -f /etc/nginx/sites-enabled/test_app ]", quiet: true)

      passenger.app_configured?
    end
  end
end