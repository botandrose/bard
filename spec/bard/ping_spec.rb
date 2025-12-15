require "spec_helper"
require "bard/ping"

describe Bard::Ping do
  let(:server) { double("server", ping: ["http://example.com"]) }
  let(:ping) { described_class.new(server) }

  def success_response
    Net::HTTPSuccess.new(1.0, "200", "OK")
  end

  def not_found_response
    Net::HTTPNotFound.new(1.0, "404", "Not Found")
  end

  context "when the server is reachable" do
    it "returns an empty array" do
      allow(ping).to receive(:http_get).and_return(success_response)
      expect(ping.call).to be_empty
    end
  end

  context "when the server is not reachable" do
    it "returns the url" do
      allow(ping).to receive(:http_get).and_return(not_found_response)
      expect(ping.call).to eq(["http://example.com"])
    end
  end

  context "when there is a redirect" do
    it "follows the redirect and returns an empty array" do
      redirect_response = Net::HTTPRedirection.new(1.0, "301", "Moved Permanently")
      redirect_response["location"] = "/new"
      allow(ping).to receive(:http_get).with(URI("http://example.com")).and_return(redirect_response)
      allow(ping).to receive(:http_get).with(URI("http://example.com/new")).and_return(success_response)
      expect(ping.call).to be_empty
    end
  end

  context "when a transient error occurs" do
    it "retries once before marking down" do
      calls = 0
      allow(ping).to receive(:http_get) do
        calls += 1
        raise Errno::ECONNRESET if calls == 1

        success_response
      end

      expect(ping.call).to be_empty
    end
  end

  context "when errors persist across retries" do
    it "returns the url" do
      allow(ping).to receive(:http_get).and_raise(Errno::ECONNREFUSED)
      expect(ping.call).to eq(["http://example.com"])
    end
  end
end
