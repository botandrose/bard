require "spec_helper"
require "bard/cli"

describe "bard ssh" do
  let(:target) { double("target") }
  let(:config) { { production: target } }
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:options).and_return({ home: false })
  end

  describe "#ssh" do
    it "should have an ssh command" do
      expect(cli).to respond_to(:ssh)
    end

    it "should execute shell on production target by default" do
      expect(target).to receive(:exec!).with("exec $SHELL -l", home: false)

      cli.ssh
    end

    it "should execute shell with home option when specified" do
      allow(cli).to receive(:options).and_return({ home: true })
      expect(target).to receive(:exec!).with("exec $SHELL -l", home: true)

      cli.ssh
    end

    it "should connect to specified target" do
      staging_server = double("staging")
      allow(config).to receive(:[]).with(:staging).and_return(staging_server)
      expect(staging_server).to receive(:exec!).with("exec $SHELL -l", home: false)

      cli.ssh(:staging)
    end
  end
end
