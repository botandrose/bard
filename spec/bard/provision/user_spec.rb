require "spec_helper"
require "bard/provision"
require "bard/provision/user"

describe Bard::Provision::User do
  let(:old_ssh_uri) { double("old_ssh_uri", user: "root", host: "example.com", port: 22) }
  let(:new_ssh_uri) { double("new_ssh_uri", user: "deploy", host: "example.com", port: 22) }
  let(:server) { double("server", ssh_uri: new_ssh_uri) }
  let(:config) { { production: server } }
  let(:ssh_url) { "root@example.com" }
  let(:provision_server) { double("provision_server", ssh_uri: old_ssh_uri) }
  let(:user_provisioner) { Bard::Provision::User.new(config, ssh_url) }

  before do
    allow(user_provisioner).to receive(:server).and_return(server)
    allow(user_provisioner).to receive(:provision_server).and_return(provision_server)
    allow(user_provisioner).to receive(:print)
    allow(user_provisioner).to receive(:puts)
    allow(user_provisioner).to receive(:system)
  end

  describe "#call" do
    context "when new user already exists" do
      it "skips user creation" do
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri, user: "deploy").and_return(true)

        expect(provision_server).not_to receive(:run!)

        user_provisioner.call
      end
    end

    context "when new user doesn't exist but old user works" do
      it "creates the new user" do
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri, user: "deploy").and_return(false)
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri).and_return(true)

        expected_commands = [
          "sudo useradd -m -s /bin/bash deploy",
          "sudo usermod -aG sudo deploy",
          "echo \"deploy ALL=(ALL) NOPASSWD:ALL\" | sudo tee -a /etc/sudoers",
          "sudo mkdir -p ~deploy/.ssh",
          "sudo cp ~/.ssh/authorized_keys ~deploy/.ssh/authorized_keys",
          "sudo chown -R deploy:deploy ~deploy/.ssh",
          "sudo chmod +rx ~deploy"
        ].join("; ")

        expect(provision_server).to receive(:run!).with(expected_commands, home: true)

        user_provisioner.call
      end

      it "prints status messages during user creation" do
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri, user: "deploy").and_return(false)
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri).and_return(true)
        allow(provision_server).to receive(:run!)

        expect(user_provisioner).to receive(:print).with("User:")
        expect(user_provisioner).to receive(:print).with(" Adding user deploy,")
        expect(user_provisioner).to receive(:puts).with(" ✓")

        user_provisioner.call
      end
    end

    context "when neither old nor new user can SSH" do
      it "raises an error" do
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri, user: "deploy").and_return(false)
        allow(user_provisioner).to receive(:ssh_with_user?).with(old_ssh_uri).and_return(false)

        expect { user_provisioner.call }.to raise_error("can't ssh in with user deploy or root")
      end
    end
  end

  describe "#ssh_with_user?" do
    it "tests SSH connection with specified user" do
      expect(user_provisioner).to receive(:system).with("ssh -o ConnectTimeout=2 -p22 deploy@example.com : >/dev/null 2>&1")

      user_provisioner.send(:ssh_with_user?, old_ssh_uri, user: "deploy")
    end

    it "uses default user from SSH URI if not specified" do
      expect(user_provisioner).to receive(:system).with("ssh -o ConnectTimeout=2 -p22 root@example.com : >/dev/null 2>&1")

      user_provisioner.send(:ssh_with_user?, old_ssh_uri)
    end
  end

  describe "private methods" do
    describe "#new_user" do
      it "returns the target user from server SSH URI" do
        expect(user_provisioner.send(:new_user)).to eq("deploy")
      end
    end

    describe "#old_user" do
      it "returns the current user from provision server SSH URI" do
        expect(user_provisioner.send(:old_user)).to eq("root")
      end
    end
  end
end