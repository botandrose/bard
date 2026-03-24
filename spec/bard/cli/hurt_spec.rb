require "spec_helper"
require "bard/cli"

describe "bard hurt" do
  let(:cli) { Bard::CLI.new }

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
