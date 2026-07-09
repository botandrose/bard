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

    describe "#data" do
      it "return an empty array" do
        expect(subject.data).to eq []
      end
    end
  end

  context "with production definition" do
    subject { described_class.new("tracker", source: <<~SOURCE) }
      target :production do
        ssh "www@ssh.botandrose.com:22022"
        url "tracker.botandrose.com"
      end

      data "public/system", "public/ckeditor"
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

    describe "#data" do
      it "returns the data setting" do
        expect(subject.data).to eq ["public/system", "public/ckeditor"]
      end
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
