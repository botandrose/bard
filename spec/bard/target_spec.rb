require "spec_helper"
require "bard/target"
require "bard/plugins/ping/target_methods"

describe Bard::Target do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) { described_class.new(:production, config) }

  describe "#initialize" do
    it "stores the target key" do
      expect(target.key).to eq(:production)
    end

    it "stores the config" do
      expect(target.config).to eq(config)
    end

    it "initializes with no capabilities" do
      expect(target.has_capability?(:ssh)).to be false
      expect(target.has_capability?(:url)).to be false
    end

  end

  describe "#ssh" do
    context "with simple SSH configuration" do
      before { target.ssh("deploy@example.com:22") }

      it "enables SSH capability" do
        expect(target.has_capability?(:ssh)).to be true
      end

      it "creates SSHServer instance" do
        expect(target.server).to be_a(Bard::SSHServer)
      end

      it "parses SSH URI" do
        expect(target.ssh_uri).to be_a(URI::Generic)
        expect(target.ssh_uri.scheme).to eq("ssh")
        expect(target.ssh_uri.user).to eq("deploy")
        expect(target.ssh_uri.host).to eq("example.com")
        expect(target.ssh_uri.port).to eq(22)
      end
    end

    context "with hash options" do
      before do
        target.ssh("deploy@example.com:22",
          path: "/var/www/app",
          gateway: "bastion@example.com:22",
          ssh_key: "/path/to/key",
          env: "RAILS_ENV=production"
        )
      end

      it "enables SSH capability" do
        expect(target.has_capability?(:ssh)).to be true
      end

      it "stores path" do
        expect(target.path).to eq("/var/www/app")
      end

      it "stores gateway" do
        expect(target.gateway).to eq("bastion@example.com:22")
      end

      it "stores SSH key" do
        expect(target.ssh_key).to eq("/path/to/key")
      end

      it "stores environment variables" do
        expect(target.env).to eq("RAILS_ENV=production")
      end

      it "auto-configures url from hostname" do
        expect(target.url).to eq("https://example.com")
      end
    end

    context "with false value" do
      before { target.ssh(false) }

      it "does not enable SSH capability" do
        expect(target.has_capability?(:ssh)).to be false
      end

      it "sets server to nil" do
        expect(target.server).to be_nil
      end
    end
  end

  describe "#url" do
    it "enables url capability" do
      target.url("https://example.com")
      expect(target.has_capability?(:url)).to be true
      expect(target.url).to eq("https://example.com")
    end

    it "normalizes URLs without scheme" do
      target.url("example.com")
      expect(target.url).to eq("https://example.com")
    end

    it "disables url with false" do
      target.url("https://example.com")
      target.url(false)
      expect(target.has_capability?(:url)).to be false
      expect(target.url).to be_nil
    end
  end

  describe "#ping" do
    it "accepts multiple URLs" do
      target.ping("https://example.com", "https://example.com/health")
      expect(target.ping).to eq(["https://example.com", "https://example.com/health"])
    end

    it "defaults to url when not explicitly set" do
      target.url("https://example.com")
      expect(target.ping).to eq(["https://example.com"])
    end

    it "returns empty array when no url or ping configured" do
      expect(target.ping).to eq([])
    end

    it "disables ping with false" do
      target.ping("https://example.com")
      target.ping(false)
      expect(target.ping).to be_empty
    end
  end

  describe "#path" do
    it "defaults to project name" do
      expect(target.path).to eq("testapp")
    end

    it "can be set via ssh options" do
      target.ssh("deploy@example.com:22", path: "/app")
      expect(target.path).to eq("/app")
    end
  end

  describe "remote command execution" do
    before do
      target.ssh("deploy@example.com:22", path: "/app")
    end

    describe "#run!" do
      it "requires SSH capability" do
        target_without_ssh = described_class.new(:staging, config)
        expect { target_without_ssh.run!("ls") }
          .to raise_error(/SSH not configured/)
      end

      it "executes command on remote server" do
        expect(Bard::Command).to receive(:run!)
          .with("ls", on: target, home: false, verbose: false, quiet: false)
        target.run!("ls")
      end
    end

    describe "#run" do
      it "requires SSH capability" do
        target_without_ssh = described_class.new(:staging, config)
        expect { target_without_ssh.run("ls") }
          .to raise_error(/SSH not configured/)
      end

      it "executes command on remote server without raising" do
        expect(Bard::Command).to receive(:run)
          .with("ls", on: target, home: false, verbose: false, quiet: false)
        target.run("ls")
      end
    end

    describe "#exec!" do
      it "requires SSH capability" do
        target_without_ssh = described_class.new(:staging, config)
        expect { target_without_ssh.exec!("ls") }
          .to raise_error(/SSH not configured/)
      end

      it "replaces process with remote command" do
        expect(Bard::Command).to receive(:exec!)
          .with("ls", on: target, home: false)
        target.exec!("ls")
      end
    end
  end

  describe "file transfer" do
    let(:source_target) do
      t = described_class.new(:source, config)
      t.ssh("source@example.com:22", path: "/source")
      t
    end

    let(:dest_target) do
      t = described_class.new(:dest, config)
      t.ssh("dest@example.com:22", path: "/dest")
      t
    end

    describe "#copy_file" do
      it "requires SSH capability on source" do
        target_without_ssh = described_class.new(:staging, config)
        expect { target_without_ssh.copy_file("test.txt", to: dest_target) }
          .to raise_error(/SSH not configured/)
      end

      it "requires SSH capability on destination" do
        target_without_ssh = described_class.new(:staging, config)
        expect { source_target.copy_file("test.txt", to: target_without_ssh) }
          .to raise_error(/SSH not configured/)
      end

      it "copies file via SCP" do
        expect(Bard::Copy).to receive(:file)
          .with("test.txt", from: source_target, to: dest_target, verbose: false)
        source_target.copy_file("test.txt", to: dest_target)
      end
    end

    describe "#copy_dir" do
      it "requires SSH capability on source" do
        target_without_ssh = described_class.new(:staging, config)
        expect { target_without_ssh.copy_dir("test/", to: dest_target) }
          .to raise_error(/SSH not configured/)
      end

      it "requires SSH capability on destination" do
        target_without_ssh = described_class.new(:staging, config)
        expect { source_target.copy_dir("test/", to: target_without_ssh) }
          .to raise_error(/SSH not configured/)
      end

      it "syncs directory via rsync" do
        expect(Bard::Copy).to receive(:dir)
          .with("test/", from: source_target, to: dest_target, verbose: false)
        source_target.copy_dir("test/", to: dest_target)
      end
    end
  end

  describe "#to_s" do
    it "returns the target key as string" do
      expect(target.to_s).to eq("production")
    end
  end

  describe "#to_sym" do
    it "returns the target key as symbol" do
      expect(target.to_sym).to eq(:production)
    end
  end
end
