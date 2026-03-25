require "spec_helper"
require "bard/cli"

describe "bard new" do
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:run!)
    allow(cli).to receive(:green).and_return("")
    allow(cli).to receive(:red).and_return("")
    allow(cli).to receive(:yellow).and_return("")
    allow(File).to receive(:read).and_return("master_key_content")
  end

  describe "#new" do
    context "with --skip-github and --skip-stage" do
      let(:cli) { Bard::CLI.new([], skip_github: true, skip_stage: true) }

      before do
        allow(cli).to receive(:new_create_project)
      end

      it "skips github and stage steps" do
        expect(cli).not_to receive(:new_push_to_github)
        expect(cli).not_to receive(:new_stage)
        cli.new("testproject")
      end
    end

    context "with invalid project name" do
      before do
        allow(cli).to receive(:new_create_project)
        allow(cli).to receive(:new_push_to_github)
        allow(cli).to receive(:new_stage)
      end

      it "should reject names starting with uppercase" do
        expect(cli).to receive(:puts).with(/Invalid project name/)
        expect(cli).to receive(:exit).with(1)

        cli.new("InvalidProject")
      end

      it "should reject names with special characters" do
        expect(cli).to receive(:puts).with(/Invalid project name/)
        expect(cli).to receive(:exit).with(1)

        cli.new("invalid-project")
      end

      it "should reject names starting with numbers" do
        expect(cli).to receive(:puts).with(/Invalid project name/)
        expect(cli).to receive(:exit).with(1)

        cli.new("1invalidproject")
      end
    end
  end

  describe "#new_ruby_version" do
    it "returns the ruby version" do
      expect(cli.send(:new_ruby_version)).to eq("ruby-4.0.2")
    end
  end

  describe "#new_template_path" do
    it "returns the path to the rails template" do
      expect(cli.send(:new_template_path)).to match(/rails_template\.rb$/)
    end
  end

  describe "#install_and_extract_version" do
    it "correctly installs a gem and extracts its version", skip: !!ENV["CI"] do
      cmd = cli.send :new_build_bash_env do
        <<~SH
          #{cli.send(:new_build_gem_install, "bundler", "~> 2.0")}
          echo ${GEM_VERSION}
        SH
      end
      result = `#{cmd}`.strip
      expect(result).to match(/^2\.\d+\.\d+/)
    end
  end
end
