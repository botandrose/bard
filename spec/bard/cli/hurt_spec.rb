require "spec_helper"
require "bard/cli"
require "bard/cli/hurt"
require "thor"

class TestHurtCLI < Thor
  Bard::CLI::Hurt.setup(self)
end

describe Bard::CLI::Hurt do
  let(:cli) { TestHurtCLI.new }

  before do
    allow(cli).to receive(:puts)
    allow(cli).to receive(:system)
  end

  describe "#hurt" do
    it "should have a hurt command" do
      expect(cli).to respond_to(:hurt)
    end
  end
end
