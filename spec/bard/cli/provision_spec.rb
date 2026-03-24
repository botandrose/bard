require "spec_helper"
require "bard/cli"

describe "bard provision" do
  let(:config) { { production: double("production", ssh: "user@example.com") } }
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:options).and_return({ steps: ["SSH", "User"] })
  end

  describe "PROVISION_STEPS constant" do
    it "defines the provisioning steps" do
      expect(Bard::CLI::PROVISION_STEPS).to include("SSH", "User", "Apt", "MySQL", "Deploy")
      expect(Bard::CLI::PROVISION_STEPS).to be_a(Array)
    end
  end

  describe "#provision" do
    it "should run provision steps" do
      expect(Bard::Provision).to receive(:const_get).with("SSH").and_return(double("ssh_step", call: true))
      expect(Bard::Provision).to receive(:const_get).with("User").and_return(double("user_step", call: true))

      cli.provision
    end

    it "should use production ssh by default" do
      allow(Bard::Provision).to receive(:const_get).and_return(double("step", call: true))

      cli.provision
    end

    it "should accept custom ssh_url" do
      custom_ssh = "root@newserver.com"
      allow(Bard::Provision).to receive(:const_get).and_return(double("step", call: true))

      cli.provision(custom_ssh)
    end
  end
end
