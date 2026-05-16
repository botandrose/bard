require "bard/config"
require "bard/plugins/ssh/target_methods"
require "bard/plugins/data"
require "bard/plugins/github_pages"

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
      it "is prefilled with default targets" do
        expect(subject.targets.keys).to eq %i[local gubs ci staging production]
      end

      it "creates Target instances for defaults" do
        subject.targets.each_value do |target|
          expect(target).to be_a(Bard::Target)
        end
      end
    end

    describe "#[]" do
      it "defines a default production target equivalent to staging" do
        expect(subject[:production]).to eq subject[:staging]
        expect(subject[:production]).not_to equal subject[:staging]
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
      it "contains the defined target" do
        expect(subject.targets.keys).to eq %i[local gubs ci staging production]
      end
    end

    describe "#target" do
      it "can overwrite existing definition" do
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

  context "with remove_target" do
    subject { described_class.new("tracker", source: <<~SOURCE) }
      remove_target :staging
      target :staging do
        ssh "deploy@new-host.com"
      end
    SOURCE

    it "replaces the default with a fresh target" do
      staging = subject[:staging]
      expect(staging).to be_a(Bard::Target)
      expect(staging.ssh.to_s).to eq "deploy@new-host.com"
      expect(staging.url).to eq "https://new-host.com"
    end
  end

  context "with github_pages directive" do
    subject { described_class.new("test", source: "github_pages 'example.com'") }

    describe "#target" do
      it "creates a production target with github_pages enabled" do
        production = subject[:production]
        expect(production).not_to be_nil
        expect(production.github_pages).to eq "example.com"
        expect(production.ssh).to be_nil
      end
    end
  end
end
