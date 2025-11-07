require "spec_helper"
require "bard/ssh_server"

describe Bard::SSHServer do
  describe "#initialize" do
    it "parses SSH URI with user, host, and port" do
      server = described_class.new("deploy@example.com:22")
      expect(server.user).to eq("deploy")
      expect(server.host).to eq("example.com")
      expect(server.port).to eq("22")
    end

    it "handles SSH URI without port (defaults to 22)" do
      server = described_class.new("deploy@example.com")
      expect(server.user).to eq("deploy")
      expect(server.host).to eq("example.com")
      expect(server.port).to eq("22")
    end

    it "handles SSH URI without user (uses current user)" do
      server = described_class.new("example.com:22")
      expect(server.host).to eq("example.com")
      expect(server.port).to eq("22")
      expect(server.user).to eq(ENV['USER'])
    end

    it "accepts options hash" do
      server = described_class.new("deploy@example.com:22",
        path: "/app",
        gateway: "bastion@example.com:22",
        ssh_key: "/path/to/key",
        env: "RAILS_ENV=production"
      )

      expect(server.path).to eq("/app")
      expect(server.gateway).to eq("bastion@example.com:22")
      expect(server.ssh_key).to eq("/path/to/key")
      expect(server.env).to eq("RAILS_ENV=production")
    end
  end

  describe "#ssh_uri" do
    it "returns the SSH connection string" do
      server = described_class.new("deploy@example.com:22")
      expect(server.ssh_uri).to eq("deploy@example.com:22")
    end

    it "includes port if non-standard" do
      server = described_class.new("deploy@example.com:2222")
      expect(server.ssh_uri).to eq("deploy@example.com:2222")
    end
  end

  describe "#hostname" do
    it "extracts hostname from SSH URI" do
      server = described_class.new("deploy@example.com:22")
      expect(server.hostname).to eq("example.com")
    end

    it "handles IP addresses" do
      server = described_class.new("deploy@192.168.1.1:22")
      expect(server.hostname).to eq("192.168.1.1")
    end
  end

  describe "#connection_string" do
    it "builds SSH connection string" do
      server = described_class.new("deploy@example.com:22")
      expect(server.connection_string).to eq("deploy@example.com")
    end

    it "includes port flag for non-standard ports" do
      server = described_class.new("deploy@example.com:2222")
      expect(server.connection_string).to include("-p 2222")
    end

    it "includes gateway if configured" do
      server = described_class.new("deploy@example.com:22",
        gateway: "bastion@example.com:22"
      )
      expect(server.connection_string).to include("ProxyJump=bastion@example.com:22")
    end

    it "includes SSH key if configured" do
      server = described_class.new("deploy@example.com:22",
        ssh_key: "/path/to/key"
      )
      expect(server.connection_string).to include("-i /path/to/key")
    end
  end

  describe "#run" do
    let(:server) do
      described_class.new("deploy@example.com:22", path: "/app")
    end

    it "executes command via SSH" do
      expect(Open3).to receive(:capture3)
        .with(/ssh.*deploy@example.com.*cd \/app && ls/)
        .and_return(["output", "", 0])

      server.run("ls")
    end

    it "includes environment variables if configured" do
      server_with_env = described_class.new("deploy@example.com:22",
        path: "/app",
        env: "RAILS_ENV=production"
      )

      expect(Open3).to receive(:capture3)
        .with(/RAILS_ENV=production/)
        .and_return(["output", "", 0])

      server_with_env.run("ls")
    end
  end

  describe "#run!" do
    let(:server) do
      described_class.new("deploy@example.com:22", path: "/app")
    end

    it "executes command via SSH" do
      expect(Open3).to receive(:capture3)
        .with(/ssh.*deploy@example.com.*cd \/app && ls/)
        .and_return(["output", "", 0])

      server.run!("ls")
    end

    it "raises error if command fails" do
      expect(Open3).to receive(:capture3)
        .and_return(["", "error", 1])

      expect { server.run!("false") }.to raise_error(Bard::Command::Error)
    end
  end

  describe "#exec!" do
    let(:server) do
      described_class.new("deploy@example.com:22", path: "/app")
    end

    it "replaces current process with SSH command" do
      expect(server).to receive(:exec)
        .with(/ssh.*deploy@example.com.*cd \/app && ls/)

      server.exec!("ls")
    end
  end

  describe "path handling" do
    it "uses path in commands if configured" do
      server = described_class.new("deploy@example.com:22", path: "/var/www/app")

      expect(Open3).to receive(:capture3)
        .with(/cd \/var\/www\/app && ls/)
        .and_return(["output", "", 0])

      server.run("ls")
    end

    it "works without path" do
      server = described_class.new("deploy@example.com:22")

      expect(Open3).to receive(:capture3)
        .with(/ssh.*ls/)
        .and_return(["output", "", 0])

      server.run("ls")
    end
  end

  describe "gateway/bastion support" do
    it "uses ProxyJump for gateway" do
      server = described_class.new("deploy@private.example.com:22",
        gateway: "bastion@public.example.com:22"
      )

      expect(Open3).to receive(:capture3)
        .with(/-o ProxyJump=bastion@public.example.com:22/)
        .and_return(["output", "", 0])

      server.run("ls")
    end
  end
end
