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
      it "returns a BackupConfig with bard enabled by default" do
        backup = subject.backup
        expect(backup).to be_a(Bard::BackupConfig)
        expect(backup.bard?).to eq true
        expect(backup.destinations).to be_empty
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

  context "with new backup block syntax" do
    describe "#backup with bard directive" do
      subject { described_class.new("test", source: "backup { bard }") }

      it "returns a BackupConfig with bard enabled" do
        backup = subject.backup
        expect(backup).to be_a(Bard::BackupConfig)
        expect(backup.bard?).to eq true
        expect(backup.destinations).to be_empty
        expect(backup.self_managed?).to eq false
      end
    end

    describe "#backup with s3 directive" do
      subject { described_class.new("test", source: "backup { s3 :primary, credentials: :backup, path: 'bucket/path' }") }

      it "returns a BackupConfig with s3 destination" do
        backup = subject.backup
        expect(backup).to be_a(Bard::BackupConfig)
        expect(backup.bard?).to eq false
        expect(backup.destinations.length).to eq 1
        expect(backup.self_managed?).to eq true

        dest = backup.destinations.first
        expect(dest[:name]).to eq :primary
        expect(dest[:type]).to eq :s3
        expect(dest[:credentials]).to eq :backup
        expect(dest[:path]).to eq 'bucket/path'
      end
    end

    describe "#backup with both bard and s3 directives" do
      subject { described_class.new("test", source: "backup { bard; s3 :custom, credentials: :backup, path: 'bucket/path' }") }

      it "returns a BackupConfig with bard and s3 destination" do
        backup = subject.backup
        expect(backup).to be_a(Bard::BackupConfig)
        expect(backup.bard?).to eq true
        expect(backup.destinations.length).to eq 1
        expect(backup.self_managed?).to eq true
      end
    end

    describe "#backup with multiple s3 destinations" do
      subject do
        described_class.new("test", source: <<~SOURCE)
          backup do
            s3 :primary, credentials: :backup1, path: 'bucket1/path'
            s3 :secondary, credentials: :backup2, path: 'bucket2/path'
          end
        SOURCE
      end

      it "returns a BackupConfig with multiple destinations" do
        backup = subject.backup
        expect(backup).to be_a(Bard::BackupConfig)
        expect(backup.bard?).to eq false
        expect(backup.destinations.length).to eq 2
        expect(backup.self_managed?).to eq true

        expect(backup.destinations[0][:name]).to eq :primary
        expect(backup.destinations[1][:name]).to eq :secondary
      end
    end

    describe "#backup true (backward compatibility)" do
      subject { described_class.new("test", source: "backup true") }

      it "returns a BackupConfig with bard enabled" do
        backup = subject.backup
        expect(backup).to be_a(Bard::BackupConfig)
        expect(backup.bard?).to eq true
        expect(backup.destinations).to be_empty
      end
    end
  end
end

