require "bard/server"

describe Bard::Server do
  subject do
    described_class.define("tracker", :production) do
      ssh "www@tracker.botandrose.com:22022"
      path "work/tracker"
      ping "tracker.botandrose.com", "www.tracker.botandrose.com"
      gateway "www@staging.botandrose.com:22022"
      ssh_key "~/.ssh/id_rsa.pub"
      env "RAILS_ENV=production"
    end
  end

  describe "#ssh" do
    it "returns the ssh setting" do
      expect(subject.ssh).to eq "www@tracker.botandrose.com:22022"
    end
  end

  describe "#ssh_uri" do
    it "exposes the host" do
      expect(subject.ssh_uri.host).to eq "tracker.botandrose.com"
    end

    it "exposes the user" do
      expect(subject.ssh_uri.user).to eq "www"
    end

    it "exposes the port" do
      expect(subject.ssh_uri.port).to eq 22022
    end

    it "has no path" do
      expect(subject.ssh_uri.path).to be_empty
    end

    it "can specify another field to read from" do
      expect(subject.ssh_uri(:gateway).host).to eq "staging.botandrose.com"
    end

    it "has no path" do
      expect(subject.ssh_uri.path).to be_empty
    end
  end

  describe "#scp_uri" do
    it "exposes the host" do
      expect(subject.scp_uri.host).to eq "tracker.botandrose.com"
    end

    it "exposes the user" do
      expect(subject.scp_uri.user).to eq "www"
    end

    it "exposes the port" do
      expect(subject.scp_uri.port).to eq 22022
    end

    it "includes the path to the project" do
      expect(subject.scp_uri.path).to eq "/work/tracker"
    end

    it "compiles to an scp:// string" do
      expect(subject.scp_uri.to_s).to eq "scp://www@tracker.botandrose.com:22022/work/tracker"
    end
  end

  describe "#rsync_uri" do
    it "works" do
      expect(subject.rsync_uri("public/assets")).to eq "www@tracker.botandrose.com:work/tracker/public/assets"
    end
  end

  describe "#path" do
    it "returns the path setting" do
      expect(subject.path).to eq "work/tracker"
    end

    it "defaults to the project name" do
      subject.path nil
      expect(subject.path).to eq "tracker"
    end
  end

  describe "#ping" do
    it "returns the ping urls, normalized" do
      expect(subject.ping).to eq [
        "https://tracker.botandrose.com",
        "https://www.tracker.botandrose.com",
      ]
    end

    it "accepts paths" do
      subject.ping "/ping"
      expect(subject.ping).to eq ["https://tracker.botandrose.com/ping"]
    end

    it "defaults to the ssh value" do
      subject.ping nil
      expect(subject.ping).to eq ["https://tracker.botandrose.com"]
    end

    it "accepts false to disable pings" do
      subject.ping false
      expect(subject.ping).to eq []
    end
  end

  describe "#gateway" do
    it "returns the gateway setting" do
      expect(subject.gateway).to eq "www@staging.botandrose.com:22022"
    end
  end

  describe "#ssh_key" do
    it "returns the ssh_key setting" do
      expect(subject.ssh_key).to eq "~/.ssh/id_rsa.pub"
    end
  end

  describe "#env" do
    it "returns the env setting" do
      expect(subject.env).to eq "RAILS_ENV=production"
    end
  end
end
