require "spec_helper"
require "bard/ping"

describe Bard::Ping do
  let(:server) { double("server", ping: ["http://example.com"]) }

  context "when the server is reachable" do
    it "should return an empty array" do
      allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPSuccess.new(1.0, "200", "OK"))
      expect(Bard::Ping.call(server)).to be_empty
    end
  end

  context "when the server is not reachable" do
    it "should return the url" do
      allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound.new(1.0, "404", "Not Found"))
      expect(Bard::Ping.call(server)).to eq(["http://example.com"])
    end
  end

  context "when there is a redirect" do
    it "should follow the redirect and return an empty array" do
      redirect_response = Net::HTTPRedirection.new(1.0, "301", "Moved Permanently")
      redirect_response["location"] = "http://example.com/new"
      success_response = Net::HTTPSuccess.new(1.0, "200", "OK")
      allow(Net::HTTP).to receive(:get_response).with(URI("http://example.com")).and_return(redirect_response)
      allow(Net::HTTP).to receive(:get_response).with(URI("http://example.com/new")).and_return(success_response)
      expect(Bard::Ping.call(server)).to be_empty
    end
  end
end
