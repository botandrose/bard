require "spec_helper"
require "bard/cli"
require "bard/cli/install"
require "thor"

class TestInstallCLI < Thor
  Bard::CLI::Install.setup(self)
end

describe Bard::CLI::Install do
  let(:cli) { TestInstallCLI.new }

  describe "#install" do
    it "should have an install command" do
      expect(cli).to respond_to(:install)
    end

    it "should copy install files to bin directory" do
      expect_any_instance_of(Bard::CLI::Install).to receive(:system).with(/cp -R .*install_files\/\* bin\//)
      expect_any_instance_of(Bard::CLI::Install).to receive(:system).with(/cp -R .*install_files\/\.github \.\//)

      cli.install
    end
  end
end
