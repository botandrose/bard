require "spec_helper"
require "bard/cli"
require "bard/cli/install"
require "thor"

class TestInstallCLI < Thor
  include Bard::CLI::Install
end

describe Bard::CLI::Install do
  let(:cli) { TestInstallCLI.new }

  describe "#install" do
    it "should have an install command" do
      expect(cli).to respond_to(:install)
    end

    it "should copy install files to bin directory" do
      expect(cli).to receive(:system).with(/cp -R .*install_files\/\* bin\//)
      expect(cli).to receive(:system).with(/cp -R .*install_files\/\.github \.\//)

      cli.install
    end
  end
end