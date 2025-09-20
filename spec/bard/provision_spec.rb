require "spec_helper"
require "bard/provision"

describe Bard::Provision do
  let(:config) { { production: double("production", key: :production) } }
  let(:ssh_url) { "user@example.com" }
  let(:provision) { Bard::Provision.new(config, ssh_url) }

  describe ".call" do
    it "creates a new instance and calls it" do
      expect_any_instance_of(Bard::Provision).to receive(:call)
      Bard::Provision.call(config, ssh_url)
    end
  end

  describe "#server" do
    it "returns the production server from config" do
      expect(provision.send(:server)).to eq(config[:production])
    end
  end

  describe "#provision_server" do
    it "returns server with ssh_url" do
      expect(config[:production]).to receive(:with).with(ssh: ssh_url)
      provision.send(:provision_server)
    end
  end
end