require "spec_helper"
require "bard/provision"
require "bard/provision/authorizedkeys"

describe Bard::Provision::AuthorizedKeys do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:authorized_keys) { Bard::Provision::AuthorizedKeys.new(config, ssh_url) }

  before do
    allow(authorized_keys).to receive(:provision_server).and_return(provision_server)
    allow(authorized_keys).to receive(:print)
    allow(authorized_keys).to receive(:puts)
  end

  describe "#call" do
    it "adds authorized keys to the server" do
      expect(provision_server).to receive(:run!).at_least(:once).with(/grep -F -q/, home: true)

      authorized_keys.call
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run!)
      expect(authorized_keys).to receive(:print).with("Authorized Keys:")
      expect(authorized_keys).to receive(:puts).with(" ✓")

      authorized_keys.call
    end
  end

  describe "KEYS constant" do
    it "should have predefined SSH keys" do
      expect(Bard::Provision::AuthorizedKeys::KEYS).to be_a(Hash)
      expect(Bard::Provision::AuthorizedKeys::KEYS).not_to be_empty
      expect(Bard::Provision::AuthorizedKeys::KEYS.keys.first).to match(/@/)
    end
  end
end