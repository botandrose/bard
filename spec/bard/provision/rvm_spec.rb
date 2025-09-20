require "spec_helper"
require "bard/provision"
require "bard/provision/rvm"

describe Bard::Provision::RVM do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:rvm) { Bard::Provision::RVM.new(config, ssh_url) }

  before do
    allow(rvm).to receive(:provision_server).and_return(provision_server)
    allow(rvm).to receive(:print)
    allow(rvm).to receive(:puts)
    allow(File).to receive(:read).with(".ruby-version").and_return("3.2.0\n")
  end

  describe "#call" do
    context "when RVM is not installed" do
      it "installs RVM and Ruby" do
        allow(provision_server).to receive(:run).with("[ -d ~/.rvm ]", quiet: true).and_return(false)

        expect(provision_server).to receive(:run!).with(/sed -i.*bashrc/)
        expect(provision_server).to receive(:run!).with("rvm install 3.2.0")

        rvm.call
      end
    end

    context "when RVM is already installed" do
      it "skips installation" do
        allow(provision_server).to receive(:run).with("[ -d ~/.rvm ]", quiet: true).and_return(true)

        expect(provision_server).not_to receive(:run!)

        rvm.call
      end
    end

    it "prints status messages" do
      allow(provision_server).to receive(:run).and_return(true)

      expect(rvm).to receive(:print).with("RVM:")
      expect(rvm).to receive(:puts).with(" ✓")

      rvm.call
    end
  end
end