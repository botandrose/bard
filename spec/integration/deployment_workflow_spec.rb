require "spec_helper"
require "bard"

describe "Deployment Workflow Integration" do
  describe "Traditional Rails app deployment" do
    it "deploys via SSH strategy" do
      config = Bard::Config.new(project_name: "railsapp")

      config.instance_eval do
        target :production do
          ssh "deploy@production.example.com:22", path: "/app"
        end

        data "public/uploads"
        backup true
      end

      # Verify target configuration
      production = config[:production]
      expect(production.has_capability?(:ssh)).to be true
      expect(production.deploy_strategy).to eq(:ssh)
      expect(production.path).to eq("/app")

      # Verify data paths configured
      expect(config.data_paths).to include("public/uploads")

      # Verify backup enabled
      expect(config.backup_enabled?).to be true

      # Verify strategy instance
      strategy = production.deploy_strategy_instance
      expect(strategy).to be_a(Bard::DeployStrategy::SSH)
      expect(strategy.target).to eq(production)
    end
  end

  describe "Serverless (Jets) deployment" do
    before do
      # Define Jets strategy for testing
      class Bard::DeployStrategy::Jets < Bard::DeployStrategy
        def initialize(target, url, **options)
          super(target)
          @url = url
          @options = options
          target.ping(url)
        end

        def deploy
          # test implementation
        end
      end
    end

    it "deploys via Jets strategy" do
      config = Bard::Config.new(project_name: "api")

      config.instance_eval do
        target :production do
          jets "https://api.example.com", run_tests: true
        end

        backup false
      end

      # Verify target configuration
      production = config[:production]
      expect(production.deploy_strategy).to eq(:jets)
      expect(production.ping_urls).to include("https://api.example.com")

      # Verify backup disabled
      expect(config.backup_enabled?).to be false

      # Verify strategy options
      options = production.strategy_options(:jets)
      expect(options[:run_tests]).to be true

      # Verify strategy instance
      strategy = production.deploy_strategy_instance
      expect(strategy).to be_a(Bard::DeployStrategy::Jets)
    end
  end

  describe "Static site (GitHub Pages) deployment" do
    it "deploys via GitHub Pages strategy" do
      config = Bard::Config.new(project_name: "site")

      config.instance_eval do
        target :production do
          github_pages "https://example.com"
        end

        backup false
      end

      # Verify target configuration
      production = config[:production]
      expect(production.deploy_strategy).to eq(:github_pages)
      expect(production.ping_urls).to include("https://example.com")

      # Verify backup disabled
      expect(config.backup_enabled?).to be false

      # Verify strategy instance
      strategy = production.deploy_strategy_instance
      expect(strategy).to be_a(Bard::DeployStrategy::GithubPages)
    end
  end

  describe "Hybrid deployment (Jets + SSH)" do
    before do
      class Bard::DeployStrategy::Jets < Bard::DeployStrategy
        def initialize(target, url, **options)
          super(target)
          @url = url
          @options = options
          target.ping(url)
        end

        def deploy
          # test implementation
        end
      end
    end

    it "supports both Jets and SSH capabilities" do
      config = Bard::Config.new(project_name: "api")

      config.instance_eval do
        target :staging do
          jets "https://staging-api.example.com"
          ssh "deploy@bastion.example.com:22", path: "/app"
        end

        backup false
      end

      # Verify target configuration
      staging = config[:staging]
      expect(staging.deploy_strategy).to eq(:jets)
      expect(staging.has_capability?(:ssh)).to be true
      expect(staging.ping_urls).to include("https://staging-api.example.com")

      # Verify both capabilities work
      expect { staging.run!("ls") }.not_to raise_error
      expect { staging.ping! }.not_to raise_error
    end
  end

  describe "Multi-target data copying" do
    it "copies data between targets with SSH" do
      config = Bard::Config.new(project_name: "app")

      config.instance_eval do
        target :production do
          ssh "deploy@production.example.com:22", path: "/app"
        end

        target :staging do
          ssh "deploy@staging.example.com:22", path: "/app"
        end

        data "public/uploads", "public/system"
      end

      production = config[:production]
      staging = config[:staging]

      # Both targets have SSH
      expect(production.has_capability?(:ssh)).to be true
      expect(staging.has_capability?(:ssh)).to be true

      # Data paths configured
      expect(config.data_paths).to include("public/uploads")
      expect(config.data_paths).to include("public/system")

      # Can copy between targets
      allow(production).to receive(:run!)
      allow(staging).to receive(:run!)

      expect { production.copy_file("db/data.sql.gz", to: staging) }
        .not_to raise_error

      expect { production.copy_dir("public/uploads", to: staging) }
        .not_to raise_error
    end
  end

  describe "Default target override" do
    it "allows overriding default staging target" do
      config = Bard::Config.new(project_name: "app")

      # Default staging uses SSH
      expect(config[:staging].has_capability?(:ssh)).to be true

      # Override with Jets
      class Bard::DeployStrategy::Jets < Bard::DeployStrategy
        def initialize(target, url, **options)
          super(target)
          @url = url
          @options = options
          target.ping(url)
        end

        def deploy
          # test implementation
        end
      end

      config.instance_eval do
        target :staging do
          jets "https://staging-api.example.com"
        end
      end

      # Staging now uses Jets
      staging = config[:staging]
      expect(staging.deploy_strategy).to eq(:jets)
      expect(staging.ping_urls).to include("https://staging-api.example.com")

      # Other defaults still work
      expect(config[:ci]).to be_a(Bard::Target)
      expect(config[:local]).to be_a(Bard::Target)
      expect(config[:gubs]).to be_a(Bard::Target)
    end
  end

  describe "Full deployment workflow" do
    it "runs complete deployment with all checks" do
      config = Bard::Config.new(project_name: "app")

      config.instance_eval do
        target :production do
          ssh "deploy@production.example.com:22", path: "/app"
          ping "https://example.com"
        end

        ci :local
        backup true
      end

      production = config[:production]

      # 1. CI check
      ci = config.ci_instance("master")
      expect(ci).to be_a(Bard::CI::Local)

      # 2. SSH capability check
      expect(production.has_capability?(:ssh)).to be true

      # 3. Deployment strategy
      strategy = production.deploy_strategy_instance
      expect(strategy).to be_a(Bard::DeployStrategy::SSH)

      # 4. Backup enabled
      expect(config.backup_enabled?).to be true

      # 5. Ping capability
      expect(production.has_capability?(:ping)).to be true
      expect(production.ping_urls).to include("https://example.com")
    end
  end

  describe "Error handling" do
    it "fails gracefully when SSH not configured" do
      config = Bard::Config.new(project_name: "app")

      config.instance_eval do
        target :production do
          # No SSH configured
        end
      end

      production = config[:production]

      expect { production.run!("ls") }
        .to raise_error(/SSH not configured for this target/)
    end

    it "fails gracefully when ping not configured" do
      config = Bard::Config.new(project_name: "app")

      config.instance_eval do
        target :production do
          ssh "deploy@production.example.com:22"
          # No ping configured
        end
      end

      production = config[:production]

      expect { production.ping! }
        .to raise_error(/Ping URL not configured for this target/)
    end

    it "fails gracefully when no strategy configured" do
      config = Bard::Config.new(project_name: "app")

      config.instance_eval do
        target :production do
          # No strategy configured
        end
      end

      production = config[:production]

      expect { production.deploy_strategy_instance }
        .to raise_error(/No deployment strategy configured/)
    end
  end
end
