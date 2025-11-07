require "spec_helper"
require "bard/config"
require "bard/default_config"

describe "Default Configuration" do
  let(:project_name) { "myapp" }
  let(:config) { Bard::Config.new(project_name: project_name) }

  describe "default targets" do
    it "defines :local target" do
      expect(config[:local]).to be_a(Bard::Target)
    end

    it "defines :ci target" do
      expect(config[:ci]).to be_a(Bard::Target)
    end

    it "defines :staging target" do
      expect(config[:staging]).to be_a(Bard::Target)
    end

    it "defines :gubs target" do
      expect(config[:gubs]).to be_a(Bard::Target)
    end
  end

  describe ":local target" do
    let(:local) { config[:local] }

    it "does not have SSH configured" do
      expect(local.has_capability?(:ssh)).to be false
    end

    it "has path set to current directory" do
      expect(local.path).to eq("./")
    end

    it "has ping URL based on project name" do
      expect(local.ping_urls).to include("#{project_name}.local")
    end
  end

  describe ":ci target" do
    let(:ci) { config[:ci] }

    it "has SSH configured to staging.botandrose.com" do
      expect(ci.has_capability?(:ssh)).to be true
      expect(ci.ssh_uri).to include("staging.botandrose.com")
      expect(ci.ssh_uri).to include("22022")
    end

    it "has path set to Jenkins workspace" do
      expect(ci.path).to eq("jobs/#{project_name}/workspace")
    end

    it "has ping disabled" do
      expect(ci.ping_urls).to be_empty
    end
  end

  describe ":staging target" do
    let(:staging) { config[:staging] }

    it "has SSH configured to staging.botandrose.com" do
      expect(staging.has_capability?(:ssh)).to be true
      expect(staging.ssh_uri).to include("staging.botandrose.com")
      expect(staging.ssh_uri).to include("22022")
    end

    it "has path set to project name" do
      expect(staging.path).to eq(project_name)
    end

    it "has ping URL based on project name" do
      expect(staging.ping_urls).to include("#{project_name}.botandrose.com")
    end
  end

  describe ":gubs target" do
    let(:gubs) { config[:gubs] }

    it "has SSH configured to cloud.hackett.world" do
      expect(gubs.has_capability?(:ssh)).to be true
      expect(gubs.ssh_uri).to include("cloud.hackett.world")
      expect(gubs.ssh_uri).to include("22022")
    end

    it "has path set to Sites directory" do
      expect(gubs.path).to eq("Sites/#{project_name}")
    end

    it "has ping disabled" do
      expect(gubs.ping_urls).to be_empty
    end
  end

  describe "overriding defaults" do
    it "allows user to override default targets" do
      config.instance_eval do
        target :staging do
          jets "https://staging-api.example.com"
        end
      end

      staging = config[:staging]
      expect(staging.deploy_strategy).to eq(:jets)
      expect(staging.ping_urls).to include("https://staging-api.example.com")
    end

    it "keeps unmodified defaults" do
      config.instance_eval do
        target :staging do
          jets "https://staging-api.example.com"
        end
      end

      # Other targets should still have defaults
      expect(config[:ci]).to be_a(Bard::Target)
      expect(config[:gubs]).to be_a(Bard::Target)
      expect(config[:local]).to be_a(Bard::Target)
    end

    it "allows adding new targets" do
      config.instance_eval do
        target :production do
          ssh "deploy@production.example.com:22"
        end
      end

      production = config[:production]
      expect(production).to be_a(Bard::Target)
      expect(production.has_capability?(:ssh)).to be true
    end

    it "allows overriding specific properties of default targets" do
      config.instance_eval do
        target :local do
          ping "http://localhost:3000"
        end
      end

      local = config[:local]
      expect(local.path).to eq("./")  # Still has default path
      expect(local.ping_urls).to include("http://localhost:3000")  # Overridden ping
    end
  end

  describe "loading order" do
    it "loads default config before user config" do
      # This ensures defaults are available even if user doesn't define them
      expect(config[:local]).to be_a(Bard::Target)
      expect(config[:ci]).to be_a(Bard::Target)
      expect(config[:staging]).to be_a(Bard::Target)
      expect(config[:gubs]).to be_a(Bard::Target)
    end
  end

  describe "project name interpolation" do
    it "uses project name in paths and URLs" do
      custom_config = Bard::Config.new(project_name: "customapp")

      expect(custom_config[:local].ping_urls).to include("customapp.local")
      expect(custom_config[:staging].path).to eq("customapp")
      expect(custom_config[:staging].ping_urls).to include("customapp.botandrose.com")
      expect(custom_config[:gubs].path).to eq("Sites/customapp")
      expect(custom_config[:ci].path).to eq("jobs/customapp/workspace")
    end
  end
end
