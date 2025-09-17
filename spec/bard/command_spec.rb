require "spec_helper"
require "bard/command"

describe Bard::Command do
  let(:remote) { double("remote", to_sym: :remote, ssh: true, env: nil, path: "/path/to", ssh_key: nil, ssh_uri: "user@example.com", gateway: nil) }

  describe ".run" do
    it "should run a command locally" do
      expect(Open3).to receive(:capture3).with("ls -l").and_return(["output", "", 0])
      Bard::Command.run "ls -l"
    end

    it "should run a command on a remote server" do
      expect(Open3).to receive(:capture3).with("ssh -tt  user@example.com 'cd /path/to && ls -l'").and_return(["output", "", 0])
      Bard::Command.run "ls -l", on: remote
    end
  end

  describe ".run!" do
    it "should run a command locally" do
      expect(Open3).to receive(:capture3).with("ls -l").and_return(["output", "", 0])
      Bard::Command.run! "ls -l"
    end

    it "should raise an error if the command fails" do
      expect(Open3).to receive(:capture3).with("ls -l").and_return(["output", "error", 1])
      expect { Bard::Command.run! "ls -l" }.to raise_error(Bard::Command::Error)
    end
  end

  describe ".exec!" do
    it "should exec a command locally" do
      expect_any_instance_of(Bard::Command).to receive(:exec).with("ls -l")
      Bard::Command.exec! "ls -l"
    end
  end
end
