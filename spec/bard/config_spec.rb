require "bard/config"

describe Bard::Config do
  context "empty" do
    subject { described_class.new("tracker") }

    describe "#project_name" do
      it "returns the project_name setting" do
        expect(subject.project_name).to eq "tracker"
      end
    end

    describe "#servers" do
      it "is prefilled with many servers" do
        expect(subject.servers.keys).to eq %i[local gubs ci staging]
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

    describe "#backup" do
      it "returns true" do
        expect(subject.backup).to eq true
      end
    end
  end

  context "with production definition" do
    subject { described_class.new("tracker", source: <<~SOURCE) }
      server :production do
        ssh "www@ssh.botandrose.com:22022"
        ping "tracker.botandrose.com"
      end

      data "public/system", "public/ckeditor"
      backup false
    SOURCE

    describe "#project_name" do
      it "returns the project_name setting" do
        expect(subject.project_name).to eq "tracker"
      end
    end

    describe "#servers" do
      it "contains the defined server" do
        expect(subject.servers.keys).to eq %i[local gubs ci staging production]
      end
    end

    describe "#server" do
      it "can overwrite existing definition" do
        subject.server :staging do
          ssh "www@tracker-staging.botandrose.com:22022"
        end
        expect(subject[:staging].ssh).to eq "www@tracker-staging.botandrose.com:22022"
      end
    end

    describe "#data" do
      it "returns the data setting" do
        expect(subject.data).to eq ["public/system", "public/ckeditor"]
      end
    end

    describe "#backup" do
      it "returns the backup setting" do
        expect(subject.backup).to eq false
      end
    end
  end
end

