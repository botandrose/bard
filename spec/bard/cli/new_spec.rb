require "spec_helper"
require "bard/cli"
require "bard/cli/new"

describe Bard::CLI::New do
  let(:new_cli) { Bard::CLI::New.new(double("cli")) }

  before do
    allow(new_cli).to receive(:puts)
    allow(new_cli).to receive(:exit)
    allow(new_cli).to receive(:run!)
    allow(new_cli).to receive(:green).and_return("")
    allow(new_cli).to receive(:red).and_return("")
    allow(new_cli).to receive(:yellow).and_return("")
    allow(File).to receive(:read).and_return("master_key_content")
  end

  describe "#new" do
    context "with invalid project name" do
      before do
        allow(new_cli).to receive(:create_project)
        allow(new_cli).to receive(:push_to_github)
        allow(new_cli).to receive(:stage)
      end

      it "should reject names starting with uppercase" do
        expect(new_cli).to receive(:puts).with(/Invalid project name/)
        expect(new_cli).to receive(:exit).with(1)

        new_cli.new("InvalidProject")
      end

      it "should reject names with special characters" do
        expect(new_cli).to receive(:puts).with(/Invalid project name/)
        expect(new_cli).to receive(:exit).with(1)

        new_cli.new("invalid-project")
      end

      it "should reject names starting with numbers" do
        expect(new_cli).to receive(:puts).with(/Invalid project name/)
        expect(new_cli).to receive(:exit).with(1)

        new_cli.new("1invalidproject")
      end
    end
  end

  describe "#ruby_version" do
    it "returns the ruby version" do
      expect(new_cli.send(:ruby_version)).to eq("ruby-3.4.2")
    end
  end

  describe "#template_path" do
    it "returns the path to the rails template" do
      expect(new_cli.send(:template_path)).to match(/new_rails_template\.rb$/)
    end
  end

  describe "#install_and_extract_version" do
    it "correctly installs a gem and extracts its version", skip: !!ENV["CI"] do
      cmd = new_cli.send :build_bash_env do
        <<~SH
          #{new_cli.send(:build_gem_install, "bundler", "~> 2.0")}
          echo ${GEM_VERSION}
        SH
      end
      result = `#{cmd}`.strip
      expect(result).to match(/^2\.\d+\.\d+/)
    end
  end
end
