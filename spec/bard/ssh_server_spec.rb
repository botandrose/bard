require "spec_helper"
require "bard/plugins/ssh/server"

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
    it "returns a URI object" do
      server = described_class.new("deploy@example.com:22")
      expect(server.ssh_uri).to be_a(URI::Generic)
      expect(server.ssh_uri.scheme).to eq("ssh")
      expect(server.ssh_uri.user).to eq("deploy")
      expect(server.ssh_uri.host).to eq("example.com")
      expect(server.ssh_uri.port).to eq(22)
    end

    it "includes port if non-standard" do
      server = described_class.new("deploy@example.com:2222")
      expect(server.ssh_uri.port).to eq(2222)
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
  end
end
