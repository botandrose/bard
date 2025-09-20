require "spec_helper"
require "bard/provision"
require "bard/provision/http"

describe Bard::Provision::HTTP do
  let(:server) { double("server", ping: ["https://example.com"]) }
  let(:config) { { production: server } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:http) { Bard::Provision::HTTP.new(config, ssh_url) }

  before do
    allow(http).to receive(:server).and_return(server)
    allow(http).to receive(:provision_server).and_return(provision_server)
    allow(provision_server).to receive_message_chain(:ssh_uri, :host).and_return("192.168.1.100")
    allow(http).to receive(:print)
    allow(http).to receive(:puts)
    allow(http).to receive(:system)
  end

  describe "#call" do
    context "when HTTP test passes" do
      it "shows success message" do
        allow(http).to receive(:system).and_return(true)

        expect(http).to receive(:puts).with(" ✓")

        http.call
      end
    end

    context "when HTTP test fails" do
      it "shows failure message" do
        allow(http).to receive(:system).and_return(false)

        expect(http).to receive(:puts).with(" !!! not serving a rails app from 192.168.1.100")

        http.call
      end
    end

    it "prints status header" do
      allow(http).to receive(:system).and_return(true)

      expect(http).to receive(:print).with("HTTP:")

      http.call
    end

    it "tests the correct URL" do
      expected_command = /curl -s --resolve example\.com:80:192\.168\.1\.100 http:\/\/example\.com/
      expect(http).to receive(:system).with(expected_command)

      http.call
    end
  end
end