require "bard/config"
require "bard/plugins/data"
require "bard/plugins/github_pages"

describe Bard::Config do
  context "empty" do
    subject { described_class.new("tracker") }

    describe "#project_name" do
      it "returns the project_name setting" do
        expect(subject.project_name).to eq "tracker"
      end
    end

    describe "#targets" do
      it "is prefilled with default targets" do
        expect(subject.targets.keys).to eq %i[local gubs ci staging]
      end

      it "creates Target instances for defaults" do
        subject.targets.each_value do |target|
          expect(target).to be_a(Bard::Target)
        end
      end
    end

    describe "#[]" do
      it "promotes staging to production when production doesn't exist" do
        expect(subject[:production]).to eq subject[:staging]
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
        ping "tracker.botandrose.com"
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

  context "with target overriding default" do
    subject { described_class.new("tracker", source: <<~SOURCE) }
      target :staging do
        ssh false
      end
    SOURCE

    it "replaces the default with the new configuration" do
      expect(subject[:staging]).to be_a(Bard::Target)
      expect(subject[:staging].ssh).to eq false
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
      expect(staging.ping).to eq ["https://new-host.com"]
    end
  end

  context "with github_pages directive" do
    subject { described_class.new("test", source: "github_pages 'example.com'") }

    describe "#target" do
      it "creates a production target with github_pages enabled" do
        production = subject[:production]
        expect(production).not_to be_nil
        expect(production.github_pages).to eq "example.com"
        expect(production.ssh).to eq false
      end
    end
  end
end
