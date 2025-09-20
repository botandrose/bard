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