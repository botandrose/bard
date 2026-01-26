require "spec_helper"
require "bard/cli"
require "bard/cli/vim"
require "thor"

class TestVimCLI < Thor
  Bard::CLI::Vim.setup(self)
end

describe Bard::CLI::Vim do
  let(:cli) { TestVimCLI.new }

  before do
    allow_any_instance_of(Bard::CLI::Vim).to receive(:exec)
  end

  describe "#vim" do
    it "should have a vim command" do
      expect(cli).to respond_to(:vim)
    end

    it "should exec vim with git diff files by default" do
      expect_any_instance_of(Bard::CLI::Vim).to receive(:exec).with("vim -p `(git diff master --name-only; git ls-files --others --exclude-standard) | grep -v '^app/assets/images/' | grep -v '^app/assets/stylesheets/' | while read f; do [ -f \"$f\" ] && ! file -b \"$f\" | grep -q \"binary\" && echo \"$f\"; done | tac`")

      cli.vim
    end

    it "should exec vim with specified branch" do
      expect_any_instance_of(Bard::CLI::Vim).to receive(:exec).with("vim -p `(git diff develop --name-only; git ls-files --others --exclude-standard) | grep -v '^app/assets/images/' | grep -v '^app/assets/stylesheets/' | while read f; do [ -f \"$f\" ] && ! file -b \"$f\" | grep -q \"binary\" && echo \"$f\"; done | tac`")

      cli.vim("develop")
    end
  end
end
