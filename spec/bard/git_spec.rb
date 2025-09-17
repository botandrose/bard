require "spec_helper"
require "bard/git"

describe Bard::Git do
  describe ".current_branch" do
    it "should return the current branch" do
      allow(Bard::Git).to receive(:`).with("git symbolic-ref HEAD 2>&1").and_return("refs/heads/master\n")
      expect(Bard::Git.current_branch).to eq("master")
    end

    it "should return false if not on a branch" do
      allow(Bard::Git).to receive(:`).with("git symbolic-ref HEAD 2>&1").and_return("fatal: ref HEAD is not a symbolic ref\n")
      expect(Bard::Git.current_branch).to be_falsey
    end
  end

  describe ".fast_forward_merge?" do
    it "should return true if the root is an ancestor of the branch" do
      allow(Bard::Git).to receive(:sha_of).with("root").and_return("root_sha")
      allow(Bard::Git).to receive(:sha_of).with("branch").and_return("branch_sha")
      allow(Bard::Git).to receive(:`).with("git merge-base root_sha branch_sha").and_return("root_sha\n")
      expect(Bard::Git.fast_forward_merge?("root", "branch")).to be_truthy
    end

    it "should return false if the root is not an ancestor of the branch" do
      allow(Bard::Git).to receive(:sha_of).with("root").and_return("root_sha")
      allow(Bard::Git).to receive(:sha_of).with("branch").and_return("branch_sha")
      allow(Bard::Git).to receive(:`).with("git merge-base root_sha branch_sha").and_return("other_sha\n")
      expect(Bard::Git.fast_forward_merge?("root", "branch")).to be_falsey
    end
  end

  describe ".up_to_date_with_remote?" do
    it "should return true if the local branch is up to date with the remote" do
      allow(Bard::Git).to receive(:sha_of).with("branch").and_return("sha")
      allow(Bard::Git).to receive(:sha_of).with("origin/branch").and_return("sha")
      expect(Bard::Git.up_to_date_with_remote?("branch")).to be_truthy
    end

    it "should return false if the local branch is not up to date with the remote" do
      allow(Bard::Git).to receive(:sha_of).with("branch").and_return("sha1")
      allow(Bard::Git).to receive(:sha_of).with("origin/branch").and_return("sha2")
      expect(Bard::Git.up_to_date_with_remote?("branch")).to be_falsey
    end
  end

  describe ".sha_of" do
    it "should return the sha of a ref" do
      allow(Bard::Git).to receive(:`).with("git rev-parse ref 2>/dev/null").and_return("sha\n")
      allow(Bard::Git).to receive(:command_succeeded?).and_return(true)
      expect(Bard::Git.sha_of("ref")).to eq("sha")
    end

    it "should return nil if the ref does not exist" do
      allow(Bard::Git).to receive(:`).with("git rev-parse ref 2>/dev/null").and_return("ref: fatal: ambiguous argument 'ref': unknown revision or path not in the working tree.\n")
      allow(Bard::Git).to receive(:command_succeeded?).and_return(false)
      expect(Bard::Git.sha_of("ref")).to be_nil
    end
  end
end

