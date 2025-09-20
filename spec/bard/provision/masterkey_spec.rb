require "spec_helper"
require "bard/provision"
require "bard/provision/masterkey"

describe Bard::Provision::MasterKey do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:master_key) { Bard::Provision::MasterKey.new(config, ssh_url) }

  before do
    allow(master_key).to receive(:provision_server).and_return(provision_server)
    allow(master_key).to receive(:print)
    allow(master_key).to receive(:puts)
  end

  describe "#call" do
    context "when master.key exists locally" do
      before do
        allow(File).to receive(:exist?).with("config/master.key").and_return(true)
      end

      it "uploads master.key if not present on server" do
        allow(provision_server).to receive(:run).with("[ -f config/master.key ]", quiet: true).and_return(false)

        copy_double = double("copy")
        expect(Bard::Copy).to receive(:new).with("config/master.key").and_return(copy_double)
        expect(copy_double).to receive(:scp_using_local).with(:to, provision_server)

        master_key.call
      end

      it "skips upload if master.key already exists on server" do
        allow(provision_server).to receive(:run).with("[ -f config/master.key ]", quiet: true).and_return(true)

        expect(Bard::Copy).not_to receive(:new)

        master_key.call
      end
    end

    context "when master.key doesn't exist locally" do
      before do
        allow(File).to receive(:exist?).with("config/master.key").and_return(false)
      end

      it "skips the upload" do
        expect(Bard::Copy).not_to receive(:new)

        master_key.call
      end
    end

    it "prints status messages" do
      allow(File).to receive(:exist?).and_return(false)

      expect(master_key).to receive(:print).with("Master Key:")
      expect(master_key).to receive(:puts).with(" ✓")

      master_key.call
    end
  end
end