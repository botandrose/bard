require "tmpdir"
require "fileutils"
require "bard/config"
require "bard/plugins/ssh/target_methods"

describe Bard::Config do
  describe ".detect_project_name" do
    let(:tmpdir) { Dir.mktmpdir("bard-detect-test") }
    after { FileUtils.rm_rf(tmpdir) }

    def init_repo(path)
      FileUtils.mkdir_p(path)
      Dir.chdir(path) do
        system("git init -q")
        system("git commit --allow-empty -q -m init")
      end
    end

    it "returns the repo dir basename when run from the main checkout" do
      repo = File.join(tmpdir, "myproject")
      init_repo(repo)

      Dir.chdir(repo) do
        expect(described_class.detect_project_name).to eq("myproject")
      end
    end

    it "returns the main repo basename when run from a sibling worktree" do
      repo = File.join(tmpdir, "myproject")
      init_repo(repo)
      Dir.chdir(repo) { system("git worktree add -q ../wt-feature -b feature") }

      Dir.chdir(File.join(tmpdir, "wt-feature")) do
        expect(described_class.detect_project_name).to eq("myproject")
      end
    end

    it "returns the main repo basename when run from a nested worktree" do
      repo = File.join(tmpdir, "myproject")
      init_repo(repo)
      Dir.chdir(repo) { system("git worktree add -q tmp/worktrees/wt-feature -b feature") }

      Dir.chdir(File.join(repo, "tmp/worktrees/wt-feature")) do
        expect(described_class.detect_project_name).to eq("myproject")
      end
    end
  end

  context "empty" do
    subject { described_class.new("tracker") }

    describe "#project_name" do
      it "returns the project_name setting" do
        expect(subject.project_name).to eq "tracker"
      end
    end

    describe "#targets" do
      it "is prefilled with the generic local target" do
        expect(subject.targets.keys).to eq %i[local]
      end

      it "creates Target instances for defaults" do
        subject.targets.each_value do |target|
          expect(target).to be_a(Bard::Target)
        end
      end
    end
  end

  context "with production definition" do
    subject { described_class.new("tracker", source: <<~SOURCE) }
      target :production do
        ssh "www@ssh.botandrose.com:22022"
        url "tracker.botandrose.com"
      end
    SOURCE

    describe "#project_name" do
      it "returns the project_name setting" do
        expect(subject.project_name).to eq "tracker"
      end
    end

    describe "#targets" do
      it "contains the defined target alongside the local default" do
        expect(subject.targets.keys).to eq %i[local production]
      end
    end

    describe "#target" do
      it "can define a target" do
        subject.target :staging do
          ssh "www@tracker-staging.botandrose.com:22022"
        end
        expect(subject[:staging].server.to_s).to eq "www@tracker-staging.botandrose.com:22022"
      end
    end
  end

  describe "unknown DSL (plugin-contributed)" do
    after { Bard::Config.strict = false }

    it "is tolerated as an attribute by default (server/test parsing)" do
      config = described_class.new("tracker", source: <<~SOURCE)
        ci :github_actions
        data "public/system", "public/ckeditor"
      SOURCE
      expect(config.ci).to eq :github_actions
      expect(config.data).to eq ["public/system", "public/ckeditor"]
    end

    it "raises in strict mode (CLI parsing) so typos surface" do
      Bard::Config.strict = true
      expect {
        described_class.new("tracker", source: "typoed_directive :oops")
      }.to raise_error(NoMethodError)
    end
  end

  describe "#remove_target" do
    subject { described_class.new("tracker") }

    it "removes a defined target" do
      subject.target :staging do
        ssh "deploy@new-host.com"
      end
      expect(subject[:staging].ssh.to_s).to eq "deploy@new-host.com"
      expect(subject[:staging].url).to eq "https://new-host.com"

      subject.remove_target :staging
      expect(subject[:staging]).to be_nil
    end
  end
end
