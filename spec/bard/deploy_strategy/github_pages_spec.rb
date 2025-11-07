require "spec_helper"
require "bard/deploy_strategy"
require "bard/deploy_strategy/github_pages"

describe Bard::DeployStrategy::GithubPages do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) do
    t = Bard::Target.new(:production, config)
    t.github_pages("https://example.com")
    t
  end
  let(:strategy) { described_class.new(target, "https://example.com") }

  describe "#initialize" do
    it "stores the URL" do
      expect(strategy.instance_variable_get(:@url)).to eq("https://example.com")
    end

    it "auto-configures ping URL" do
      new_target = Bard::Target.new(:production, config)
      described_class.new(new_target, "https://example.com")

      expect(new_target.ping_urls).to include("https://example.com")
    end
  end

  describe "#deploy" do
    it "does not require SSH capability" do
      expect { strategy.deploy }.not_to raise_error
    end

    it "starts Rails server locally" do
      expect(strategy).to receive(:system!)
        .with(/rails server/)

      allow(strategy).to receive(:system!).with(/wget/)
      allow(strategy).to receive(:run!)
      allow(strategy).to receive(:cleanup)

      strategy.deploy
    end

    it "mirrors site with wget" do
      allow(strategy).to receive(:system!).with(/rails server/)

      expect(strategy).to receive(:system!)
        .with(/wget.*https:\/\/example.com/)

      allow(strategy).to receive(:run!)
      allow(strategy).to receive(:cleanup)

      strategy.deploy
    end

    it "creates orphan commit with static assets" do
      allow(strategy).to receive(:system!)

      expect(strategy).to receive(:run!)
        .with(/git checkout --orphan gh-pages/)

      allow(strategy).to receive(:run!).with(/git add/)
      allow(strategy).to receive(:run!).with(/git commit/)
      allow(strategy).to receive(:run!).with(/git push/)
      allow(strategy).to receive(:cleanup)

      strategy.deploy
    end

    it "force-pushes to gh-pages branch" do
      allow(strategy).to receive(:system!)
      allow(strategy).to receive(:run!).with(/git checkout/)
      allow(strategy).to receive(:run!).with(/git add/)
      allow(strategy).to receive(:run!).with(/git commit/)

      expect(strategy).to receive(:run!)
        .with(/git push.*--force.*gh-pages/)

      allow(strategy).to receive(:cleanup)

      strategy.deploy
    end

    it "cleans up temporary files" do
      allow(strategy).to receive(:system!)
      allow(strategy).to receive(:run!)

      expect(strategy).to receive(:cleanup)

      strategy.deploy
    end
  end

  describe "auto-registration" do
    it "registers as :github_pages strategy" do
      expect(Bard::DeployStrategy[:github_pages]).to eq(described_class)
    end
  end

  describe "integration with target" do
    it "is enabled by github_pages DSL method" do
      new_target = Bard::Target.new(:production, config)
      new_target.github_pages("https://example.com")

      expect(new_target.deploy_strategy).to eq(:github_pages)
      expect(new_target.ping_urls).to include("https://example.com")
    end
  end
end
