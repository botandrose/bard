require "spec_helper"
require "bard/provision"
require "bard/provision/mysql"

describe Bard::Provision::MySQL do
  let(:config) { { production: double("production") } }
  let(:ssh_url) { "user@example.com" }
  let(:provision_server) { double("provision_server") }
  let(:mysql) { Bard::Provision::MySQL.new(config, ssh_url) }

  before do
    allow(mysql).to receive(:provision_server).and_return(provision_server)
    allow(mysql).to receive(:print)
    allow(mysql).to receive(:puts)
  end

  describe "#call" do
    context "when MySQL is not responding" do
      it "installs MySQL" do
        allow(mysql).to receive(:mysql_responding?).and_return(false)

        expect(provision_server).to receive(:run!).with(/sudo apt-get install -y mysql-server/, home: true)

        mysql.call
      end
    end

    context "when MySQL is already responding" do
      it "skips installation" do
        allow(mysql).to receive(:mysql_responding?).and_return(true)

        expect(provision_server).not_to receive(:run!)

        mysql.call
      end
    end

    it "prints status messages" do
      allow(mysql).to receive(:mysql_responding?).and_return(true)

      expect(mysql).to receive(:print).with("MySQL:")
      expect(mysql).to receive(:puts).with(" ✓")

      mysql.call
    end
  end

  describe "#mysql_responding?" do
    it "checks if MySQL service is active" do
      expect(provision_server).to receive(:run).with("sudo systemctl is-active --quiet mysql", home: true, quiet: true)

      mysql.mysql_responding?
    end
  end
end