require "spec_helper"
require "bard/plugins/provision/base"

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

  describe "#target" do
    it "returns the production target from config" do
      expect(provision.send(:target)).to eq(config[:production])
    end
  end

  describe "#provision_server" do
    it "returns target with ssh_url" do
      expect(config[:production]).to receive(:with).with(ssh: ssh_url)
      provision.send(:provision_server)
    end
  end
end