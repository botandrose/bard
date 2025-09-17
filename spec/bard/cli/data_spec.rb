require "spec_helper"
require "bard/cli"
require "bard/cli/data"

require "thor"

require "term/ansicolor"

class TestCLI < Thor
  include Bard::CLI::Data
  include Term::ANSIColor

  attr_reader :config

  def initialize
    @config = {}
  end

  def options
    {}
  end
end

describe Bard::CLI::Data do
  let(:cli) { TestCLI.new }

  it "should have a data command" do
    expect(cli).to respond_to(:data)
  end

  context "data" do
    let(:from) { double("from", key: :production, run!: nil, copy_file: nil, copy_dir: nil) }
    let(:to) { double("to", key: :local, run!: nil) }

    let(:config) do
      double("config", data: [], :[] => nil).tap do |config|
        allow(config).to receive(:[]).with("production").and_return(from)
        allow(config).to receive(:[]).with("local").and_return(to)
      end
    end

    before do
      allow(cli).to receive(:config).and_return(config)
      allow(cli).to receive(:options).and_return({from: "production", to: "local"})
    end

    it "should run the data command" do
      expect(from).to receive(:run!).with("bin/rake db:dump")
      expect(from).to receive(:copy_file).with("db/data.sql.gz", to: to, verbose: true)
      expect(to).to receive(:run!).with("bin/rake db:load")
      cli.data
    end

    context "pushing to production" do
      let(:to) { double("to", key: :production, ping: ["https://example.com"]) }

      before do
        allow(cli).to receive(:options).and_return({from: "local", to: "production"})
        allow(config).to receive(:[]).with("production").and_return(to)
        allow(config).to receive(:[]).with("local").and_return(from)
      end

      it "should prevent pushing to production if the user does not confirm" do
        expect(cli).to receive(:ask).and_return("no")
        expect { cli.data }.to raise_error(SystemExit)
      end

      it "should allow pushing to production if the user confirms" do
        expect(cli).to receive(:ask).and_return("https://example.com")
        expect(from).to receive(:run!).with("bin/rake db:dump")
        expect(from).to receive(:copy_file).with("db/data.sql.gz", to: to, verbose: true)
        expect(to).to receive(:run!).with("bin/rake db:load")
        cli.data
      end
    end
  end
end
