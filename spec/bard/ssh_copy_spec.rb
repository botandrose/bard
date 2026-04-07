require "spec_helper"
require "bard/plugins/ssh/copy"

describe Bard::SSH::Copy do
  let(:ssh_server) { double("ssh_server", gateway: nil, ssh_key: nil, port: "22", ssh_uri: double(port: 22, user: "user", host: "example.com")) }
  let(:production) { double("production", key: :production, server: ssh_server, scp_uri: "user@example.com:/path/to/file", rsync_uri: "user@example.com:/path/to/", path: "/path/to", has_capability?: true) }
  let(:local) { double("local", key: :local, has_capability?: false) }

  describe ".can_handle?" do
    it "handles pairs where at least one target has ssh capability" do
      expect(Bard::SSH::Copy.can_handle?(local, production)).to be true
      expect(Bard::SSH::Copy.can_handle?(production, local)).to be true
      expect(Bard::SSH::Copy.can_handle?(production, production)).to be true
    end

    it "does not handle pairs where neither target has ssh capability" do
      expect(Bard::SSH::Copy.can_handle?(local, local)).to be false
    end
  end

  context ".file via Bard::Copy dispatch" do
    it "should copy a file from a remote server to the local machine" do
      expect(Bard::Command).to receive(:run!).with("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR user@example.com:/path/to/file path/to/file", verbose: false)
      Bard::Copy.file "path/to/file", from: production, to: local
    end

    it "should copy a file from the local machine to a remote server" do
      expect(Bard::Command).to receive(:run!).with("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR path/to/file user@example.com:/path/to/file", verbose: false)
      Bard::Copy.file "path/to/file", from: local, to: production
    end
  end

  context ".dir via Bard::Copy dispatch" do
    it "should copy a directory from a remote server to the local machine" do
      expect(Bard::Command).to receive(:run!).with("rsync -e'ssh  -p22' --delete --info=progress2 -az user@example.com:/path/to/ ./path/", verbose: false)
      Bard::Copy.dir "path/to", from: production, to: local
    end

    it "should copy a directory from the local machine to a remote server" do
      expect(Bard::Command).to receive(:run!).with("rsync -e'ssh  -p22' --delete --info=progress2 -az ./path/to user@example.com:/path/to/", verbose: false)
      Bard::Copy.dir "path/to", from: local, to: production
    end
  end
end
