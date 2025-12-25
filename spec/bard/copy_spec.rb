require "spec_helper"
require "bard/copy"

describe Bard::Copy do
  let(:production) { double("production", key: :production, scp_uri: "user@example.com:/path/to/file", rsync_uri: "user@example.com:/path/to/", gateway: nil, ssh_key: nil, port: "22", path: "/path/to") }
  let(:local) { double("local", key: :local) }

  context ".file" do
    it "should copy a file from a remote server to the local machine" do
      expect(Bard::Command).to receive(:run!).with("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR user@example.com:/path/to/file path/to/file", verbose: false)
      Bard::Copy.file "path/to/file", from: production, to: local
    end

    it "should copy a file from the local machine to a remote server" do
      expect(Bard::Command).to receive(:run!).with("scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR path/to/file user@example.com:/path/to/file", verbose: false)
      Bard::Copy.file "path/to/file", from: local, to: production
    end
  end

  context ".dir" do
    it "should copy a directory from a remote server to the local machine" do
      allow(production).to receive_message_chain("ssh_uri.port").and_return(22)
      expect(Bard::Command).to receive(:run!).with("rsync -e'ssh  -p22' --delete --info=progress2 -az user@example.com:/path/to/ ./path/", verbose: false)
      Bard::Copy.dir "path/to", from: production, to: local
    end

    it "should copy a directory from the local machine to a remote server" do
      allow(production).to receive_message_chain("ssh_uri.port").and_return(22)
      expect(Bard::Command).to receive(:run!).with("rsync -e'ssh  -p22' --delete --info=progress2 -az ./path/to user@example.com:/path/to/", verbose: false)
      Bard::Copy.dir "path/to", from: local, to: production
    end
  end
end
