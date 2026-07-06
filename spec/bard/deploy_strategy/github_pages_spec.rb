require "spec_helper"
require "bard/plugins/github_pages/strategy"
require "bard/plugins/github_pages"

describe Bard::DeployStrategy::GithubPages do
  let(:config) { double("config", project_name: "testapp") }

  def build_shell_for(target)
    strategy = described_class.new(target)
    strategy.instance_variable_set(:@sha, "abc123")
    strategy.instance_variable_set(:@build_dir, "tmp/github-build-abc123")
    strategy.instance_variable_set(:@port, 4321)
    strategy.instance_variable_set(:@domain, strategy.send(:extract_domain))

    captured = []
    allow(strategy).to receive(:run!) { |cmd| captured << cmd }
    allow(strategy).to receive(:system)
    strategy.send(:build_site)
    captured.join("\n")
  end

  context "with no custom domain (project page under /<repo>/)" do
    let(:target) do
      Bard::Target.new(:production, config).tap { |t| t.github_pages(nil) }
    end

    it "mirrors with --convert-links so the tree is relocatable under the subpath" do
      expect(build_shell_for(target)).to match(/wget .*\s-k\s/)
    end

    it "strips the localhost prefix wget bakes into un-crawled links" do
      expect(build_shell_for(target))
        .to include(%(sed -i "s#http://localhost:$PORT/#/#g"))
    end

    it "does not write a CNAME" do
      expect(build_shell_for(target)).not_to match(/> CNAME/)
    end
  end

  context "with a custom domain (served at the domain root)" do
    let(:target) do
      Bard::Target.new(:production, config).tap { |t| t.github_pages("example.com") }
    end

    it "does not add --convert-links" do
      expect(build_shell_for(target)).not_to match(/wget .*\s-k\s/)
    end

    it "does not run the localhost strip" do
      expect(build_shell_for(target)).not_to include("localhost:$PORT/#")
    end

    it "writes the CNAME" do
      expect(build_shell_for(target)).to match(/echo example\.com > CNAME/)
    end
  end
end
