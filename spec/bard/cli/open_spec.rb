require "spec_helper"
require "bard/cli"

describe "bard open" do
  let(:target) { double("target", url: "https://example.com") }
  let(:config) { { production: target } }
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:project_name).and_return("test_project")
    allow(cli).to receive(:exec)
  end

  describe "#open" do
    it "should have an open command" do
      expect(cli).to respond_to(:open)
    end

    it "should open production target URL by default" do
      expect(cli).to receive(:exec).with("xdg-open https://example.com")

      cli.open
    end

    it "should open specified target URL" do
      staging_server = double("staging", url: "https://staging.example.com")
      allow(config).to receive(:[]).with(:staging).and_return(staging_server)

      expect(cli).to receive(:exec).with("xdg-open https://staging.example.com")

      cli.open(:staging)
    end

    it "should open CI URL when target is ci" do
      expect(cli).to receive(:exec).with("xdg-open https://github.com/botandrosedesign/test_project/actions/workflows/ci.yml")

      cli.open(:ci)
    end
  end

  describe "#open_url" do
    it "returns CI URL for ci target" do
      expect(cli.open_url(:ci)).to eq("https://github.com/botandrosedesign/test_project/actions/workflows/ci.yml")
    end

    it "returns target url for other targets" do
      expect(cli.open_url(:production)).to eq("https://example.com")
    end
  end
end
