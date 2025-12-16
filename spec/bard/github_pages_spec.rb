require "spec_helper"
require "bard/github_pages"

describe Bard::GithubPages do
  let(:server) { double("server", ping: ["https://example.com"]) }
  let(:github_pages) { Bard::GithubPages.new(double) }

  before do
    allow(Bard::Git).to receive(:sha_of).and_return("abc123")
    allow(Bard::Git).to receive(:current_branch).and_return("main")
    allow(github_pages).to receive(:system)
    allow(github_pages).to receive(:run!)
    allow(github_pages).to receive(:puts)
  end

  describe "#deploy" do
    it "performs the deployment steps" do
      expect(github_pages).to receive(:build_site)
      expect(github_pages).to receive(:create_tree_from_build).and_return("tree123")
      expect(github_pages).to receive(:create_commit).with("tree123").and_return("commit123")
      expect(github_pages).to receive(:commit_and_push).with("commit123")

      github_pages.deploy(server)
    end

    it "sets instance variables" do
      allow(github_pages).to receive(:build_site)
      allow(github_pages).to receive(:create_tree_from_build).and_return("tree123")
      allow(github_pages).to receive(:create_commit).and_return("commit123")
      allow(github_pages).to receive(:commit_and_push)

      github_pages.deploy(server)

      expect(github_pages.instance_variable_get(:@sha)).to eq("abc123")
      expect(github_pages.instance_variable_get(:@build_dir)).to eq("tmp/github-build-abc123")
      expect(github_pages.instance_variable_get(:@branch)).to eq("gh-pages")
      expect(github_pages.instance_variable_get(:@domain)).to eq("example.com")
    end
  end

  describe "#build_site" do
    it "uses the locked port" do
      github_pages.instance_variable_set(:@sha, "abc123")
      github_pages.instance_variable_set(:@build_dir, "tmp/github-build-abc123")
      github_pages.instance_variable_set(:@domain, "example.com")

      allow(github_pages).to receive(:with_locked_port).and_yield(3005)

      expect(github_pages).to receive(:run!).with(satisfy { |cmd|
        cmd.include?("rails s -p 3005") && cmd.include?("http://localhost:3005")
      }).ordered

      expect(github_pages).to receive(:run!).with(include("kill")).ordered

      github_pages.send(:build_site)
    end
  end

  describe "#with_locked_port" do
    let(:file_mock) { double("file", close: true) }

    before do
      allow(File).to receive(:open).and_return(file_mock)
    end

    it "yields the first available port" do
      allow(file_mock).to receive(:flock).and_return(true)
      
      expect(File).to receive(:open).with("/tmp/bard_github_pages_3000.lock", anything, anything)
      
      yielded_port = nil
      github_pages.send(:with_locked_port) { |p| yielded_port = p }
      expect(yielded_port).to eq(3000)
    end

    it "retries if the first port is locked" do
      # 1. Try port 3000
      expect(File).to receive(:open).with("/tmp/bard_github_pages_3000.lock", anything, anything).ordered
      expect(file_mock).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(false).ordered
      expect(file_mock).to receive(:close).ordered

      # 2. Try port 3001
      expect(File).to receive(:open).with("/tmp/bard_github_pages_3001.lock", anything, anything).ordered
      expect(file_mock).to receive(:flock).with(File::LOCK_EX | File::LOCK_NB).and_return(true).ordered
      
      # 3. Cleanup after yielding
      expect(file_mock).to receive(:flock).with(File::LOCK_UN).ordered
      expect(file_mock).to receive(:close).ordered

      yielded_port = nil
      github_pages.send(:with_locked_port) { |p| yielded_port = p }
      expect(yielded_port).to eq(3001)
    end

    it "raises an error if no ports are available" do
      allow(file_mock).to receive(:flock).and_return(false)
      
      expect {
        github_pages.send(:with_locked_port) {}
      }.to raise_error(/Could not find an available port/)
    end
  end

  describe "#get_parent_commit" do
    it "returns the sha of the gh-pages branch" do
      github_pages.instance_variable_set(:@branch, "gh-pages")
      expect(Bard::Git).to receive(:sha_of).with("gh-pages^{commit}")
      github_pages.send(:get_parent_commit)
    end
  end

  describe "#branch_exists?" do
    it "checks if branch exists using git show-ref" do
      github_pages.instance_variable_set(:@branch, "gh-pages")
      expect(github_pages).to receive(:system).with("git show-ref --verify --quiet refs/heads/gh-pages")
      github_pages.send(:branch_exists?)
    end
  end

  describe "#commit_and_push" do
    before do
      github_pages.instance_variable_set(:@branch, "gh-pages")
    end

    context "when branch exists" do
      it "updates the ref and pushes" do
        allow(github_pages).to receive(:branch_exists?).and_return(true)
        expect(github_pages).to receive(:run!).with("git update-ref refs/heads/gh-pages commit123")
        expect(github_pages).to receive(:run!).with("git push -f origin gh-pages:refs/heads/gh-pages")
        github_pages.send(:commit_and_push, "commit123")
      end
    end

    context "when branch doesn't exist" do
      it "creates the branch and pushes" do
        allow(github_pages).to receive(:branch_exists?).and_return(false)
        expect(github_pages).to receive(:run!).with("git branch gh-pages commit123")
        expect(github_pages).to receive(:run!).with("git push -f origin gh-pages:refs/heads/gh-pages")
        github_pages.send(:commit_and_push, "commit123")
      end
    end
  end
end
