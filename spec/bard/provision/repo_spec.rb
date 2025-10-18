require "spec_helper"
require "bard/provision"
require "bard/provision/repo"

describe Bard::Provision::Repo do
  let(:ssh_uri) { double("ssh_uri", user: "deploy", host: "example.com") }
  let(:server) { double("server", ssh_uri: ssh_uri, project_name: "test_project") }
  let(:config) { { production: server } }
  let(:ssh_url) { "deploy@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:github_api) { double("github_api") }
  let(:repo_provisioner) { Bard::Provision::Repo.new(config, ssh_url) }

  before do
    allow(repo_provisioner).to receive(:server).and_return(server)
    allow(repo_provisioner).to receive(:provision_server).and_return(provision_server)
    allow(repo_provisioner).to receive(:print)
    allow(repo_provisioner).to receive(:puts)
    allow(Bard::Github).to receive(:new).and_return(github_api)
  end

  describe "#call" do
    context "when repository is already cloned" do
      context "when not on latest master" do
        it "updates to latest master" do
          allow(repo_provisioner).to receive(:already_cloned?).and_return(true)
          allow(repo_provisioner).to receive(:on_latest_master?).and_return(false)

          expect(repo_provisioner).to receive(:update_to_latest_master!)
          expect(github_api).not_to receive(:add_deploy_key)

          repo_provisioner.call
        end

        it "prints status message when updating to latest master" do
          allow(repo_provisioner).to receive(:already_cloned?).and_return(true)
          allow(repo_provisioner).to receive(:on_latest_master?).and_return(false)
          allow(repo_provisioner).to receive(:update_to_latest_master!)

          expect(repo_provisioner).to receive(:print).with("Repo:")
          expect(repo_provisioner).to receive(:print).with(" Updating to latest master,")
          expect(repo_provisioner).to receive(:puts).with(" ✓")

          repo_provisioner.call
        end
      end

      context "when already on latest master" do
        it "skips update" do
          allow(repo_provisioner).to receive(:already_cloned?).and_return(true)
          allow(repo_provisioner).to receive(:on_latest_master?).and_return(true)

          expect(repo_provisioner).not_to receive(:update_to_latest_master!)
          expect(github_api).not_to receive(:add_deploy_key)

          repo_provisioner.call
        end

        it "only prints repo header and checkbox" do
          allow(repo_provisioner).to receive(:already_cloned?).and_return(true)
          allow(repo_provisioner).to receive(:on_latest_master?).and_return(true)

          expect(repo_provisioner).to receive(:print).with("Repo:")
          expect(repo_provisioner).not_to receive(:print).with(" Updating to latest master,")
          expect(repo_provisioner).to receive(:puts).with(" ✓")

          repo_provisioner.call
        end
      end
    end

    context "when repository is not cloned but can be cloned" do
      it "clones the repository directly" do
        allow(repo_provisioner).to receive(:already_cloned?).and_return(false)
        allow(repo_provisioner).to receive(:can_clone_project?).and_return(true)

        expect(provision_server).to receive(:run!).with("git clone git@github.com:botandrosedesign/test_project", home: true)
        expect(github_api).not_to receive(:add_deploy_key)

        repo_provisioner.call
      end
    end

    context "when repository cannot be cloned and SSH keypair exists" do
      it "adds deploy key and clones repository" do
        allow(repo_provisioner).to receive(:already_cloned?).and_return(false)
        allow(repo_provisioner).to receive(:can_clone_project?).and_return(false)
        allow(repo_provisioner).to receive(:ssh_keypair?).and_return(true)
        allow(provision_server).to receive(:run).with("cat ~/.ssh/id_rsa.pub", home: true).and_return("ssh-rsa AAAAB3...")

        expect(github_api).to receive(:add_deploy_key).with(title: "deploy@example.com", key: "ssh-rsa AAAAB3...")
        expect(provision_server).to receive(:run!).with("git clone git@github.com:botandrosedesign/test_project", home: true)

        repo_provisioner.call
      end
    end

    context "when repository cannot be cloned and no SSH keypair exists" do
      it "generates keypair, adds deploy key, and clones repository" do
        allow(repo_provisioner).to receive(:already_cloned?).and_return(false)
        allow(repo_provisioner).to receive(:can_clone_project?).and_return(false)
        allow(repo_provisioner).to receive(:ssh_keypair?).and_return(false)
        allow(provision_server).to receive(:run).with("cat ~/.ssh/id_rsa.pub", home: true).and_return("ssh-rsa AAAAB3...")

        expect(provision_server).to receive(:run!).with('ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N ""', home: true)
        expect(github_api).to receive(:add_deploy_key).with(title: "deploy@example.com", key: "ssh-rsa AAAAB3...")
        expect(provision_server).to receive(:run!).with("git clone git@github.com:botandrosedesign/test_project", home: true)

        repo_provisioner.call
      end

      it "prints status messages during setup" do
        allow(repo_provisioner).to receive(:already_cloned?).and_return(false)
        allow(repo_provisioner).to receive(:can_clone_project?).and_return(false)
        allow(repo_provisioner).to receive(:ssh_keypair?).and_return(false)
        allow(provision_server).to receive(:run).and_return("ssh-rsa AAAAB3...")
        allow(provision_server).to receive(:run!)
        allow(github_api).to receive(:add_deploy_key)

        expect(repo_provisioner).to receive(:print).with("Repo:")
        expect(repo_provisioner).to receive(:print).with(" Generating keypair in ~/.ssh,")
        expect(repo_provisioner).to receive(:print).with(" Add public key to GitHub repo deploy keys,")
        expect(repo_provisioner).to receive(:print).with(" Cloning repo,")
        expect(repo_provisioner).to receive(:puts).with(" ✓")

        repo_provisioner.call
      end
    end

    it "always prints success message" do
      allow(repo_provisioner).to receive(:already_cloned?).and_return(true)
      allow(repo_provisioner).to receive(:on_latest_master?).and_return(true)

      expect(repo_provisioner).to receive(:print).with("Repo:")
      expect(repo_provisioner).to receive(:puts).with(" ✓")

      repo_provisioner.call
    end
  end

  describe "private methods" do
    describe "#ssh_keypair?" do
      it "checks if SSH public key exists" do
        expect(provision_server).to receive(:run).with("[ -f ~/.ssh/id_rsa.pub ]", home: true, quiet: true)

        repo_provisioner.send(:ssh_keypair?)
      end
    end

    describe "#already_cloned?" do
      it "checks if git directory exists" do
        expect(provision_server).to receive(:run).with("[ -d ~/test_project/.git ]", home: true, quiet: true)

        repo_provisioner.send(:already_cloned?)
      end
    end

    describe "#can_clone_project?" do
      it "tests if repository can be cloned" do
        expected_commands = [
          "needle=$(ssh-keyscan -t ed25519 github.com 2>/dev/null | cut -d \" \" -f 2-3)",
          "grep -q \"$needle\" ~/.ssh/known_hosts || ssh-keyscan -H github.com >> ~/.ssh/known_hosts 2>/dev/null",
          "git ls-remote git@github.com:botandrosedesign/test_project"
        ].join("; ")

        expect(provision_server).to receive(:run).with(expected_commands, home: true, quiet: true)

        repo_provisioner.send(:can_clone_project?)
      end
    end

    describe "#project_name" do
      it "returns the server's project name" do
        expect(repo_provisioner.send(:project_name)).to eq("test_project")
      end
    end

    describe "#on_latest_master?" do
      it "checks if current HEAD matches origin/master after fetching" do
        expected_command = "cd ~/test_project && git fetch origin && [ $(git rev-parse HEAD) = $(git rev-parse origin/master) ]"
        expect(provision_server).to receive(:run).with(expected_command, home: true, quiet: true)

        repo_provisioner.send(:on_latest_master?)
      end

      it "returns true when on latest master" do
        allow(provision_server).to receive(:run).and_return(true)

        expect(repo_provisioner.send(:on_latest_master?)).to be true
      end

      it "returns false when not on latest master" do
        allow(provision_server).to receive(:run).and_return(false)

        expect(repo_provisioner.send(:on_latest_master?)).to be false
      end
    end

    describe "#update_to_latest_master!" do
      it "checks out master and resets to origin/master" do
        expected_command = "cd ~/test_project && git checkout master && git reset --hard origin/master"
        expect(provision_server).to receive(:run!).with(expected_command, home: true)

        repo_provisioner.send(:update_to_latest_master!)
      end
    end
  end
end