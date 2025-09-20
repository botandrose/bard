require "spec_helper"
require "bard/cli"
require "bard/cli/vim"
require "thor"

class TestVimCLI < Thor
  include Bard::CLI::Vim
end

describe Bard::CLI::Vim do
  let(:cli) { TestVimCLI.new }

  before do
    allow(cli).to receive(:exec)
  end

  describe "#vim" do
    it "should have a vim command" do
      expect(cli).to respond_to(:vim)
    end

    it "should exec vim with git diff files by default" do
      expect(cli).to receive(:exec).with("vim -p `git diff master --name-only | grep -v sass$ | tac`")

      cli.vim
    end

    it "should exec vim with specified branch" do
      expect(cli).to receive(:exec).with("vim -p `git diff develop --name-only | grep -v sass$ | tac`")

      cli.vim("develop")
    end
  end
end