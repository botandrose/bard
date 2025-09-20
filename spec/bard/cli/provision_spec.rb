require "spec_helper"
require "bard/cli"
require "bard/cli/provision"

describe Bard::CLI::Provision do
  let(:config) { { production: double("production", ssh: "user@example.com") } }
  let(:provision_cli) { Bard::CLI::Provision.new(double("cli")) }

  before do
    allow(provision_cli).to receive(:config).and_return(config)
    allow(provision_cli).to receive(:options).and_return({ steps: ["SSH", "User"] })
  end

  describe "STEPS constant" do
    it "defines the provisioning steps" do
      expect(Bard::CLI::Provision::STEPS).to include("SSH", "User", "Apt", "MySQL", "Deploy")
      expect(Bard::CLI::Provision::STEPS).to be_a(Array)
    end
  end

  describe "#provision" do
    it "should run provision steps" do
      expect(Bard::Provision).to receive(:const_get).with("SSH").and_return(double("ssh_step", call: true))
      expect(Bard::Provision).to receive(:const_get).with("User").and_return(double("user_step", call: true))

      provision_cli.provision
    end

    it "should use production ssh by default" do
      allow(Bard::Provision).to receive(:const_get).and_return(double("step", call: true))

      provision_cli.provision
    end

    it "should accept custom ssh_url" do
      custom_ssh = "root@newserver.com"
      allow(Bard::Provision).to receive(:const_get).and_return(double("step", call: true))

      provision_cli.provision(custom_ssh)
    end
  end
end