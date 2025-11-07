require "spec_helper"
require "bard/config"
require "bard/cli/data"

describe "Data Capability" do
  let(:config) { Bard::Config.new(project_name: "testapp") }

  let(:production) do
    t = Bard::Target.new(:production, config)
    t.ssh("deploy@production.example.com:22", path: "/app")
    t
  end

  let(:staging) do
    t = Bard::Target.new(:staging, config)
    t.ssh("deploy@staging.example.com:22", path: "/app")
    t
  end

  let(:local) do
    t = Bard::Target.new(:local, config)
    t.path("./")
    t
  end

  describe "database syncing" do
    it "requires SSH on source target" do
      config.instance_variable_set(:@targets, { production: production, local: local })

      expect { Bard::CLI::Data.new.sync(from: local, to: production) }
        .to raise_error(/SSH not configured/)
    end

    it "requires SSH on destination target" do
      config.instance_variable_set(:@targets, { production: production, local: local })

      expect { Bard::CLI::Data.new.sync(from: production, to: local) }
        .to raise_error(/SSH not configured/)
    end

    it "runs db:dump on source" do
      config.instance_variable_set(:@targets, { production: production, staging: staging })

      expect(production).to receive(:run!)
        .with(/bin\/rake db:dump/)

      allow(production).to receive(:copy_file)
      allow(staging).to receive(:run!)

      Bard::CLI::Data.new.sync(from: production, to: staging)
    end

    it "copies db/data.sql.gz via SCP" do
      config.instance_variable_set(:@targets, { production: production, staging: staging })

      allow(production).to receive(:run!)

      expect(production).to receive(:copy_file)
        .with("db/data.sql.gz", to: staging)

      allow(staging).to receive(:run!)

      Bard::CLI::Data.new.sync(from: production, to: staging)
    end

    it "runs db:load on destination" do
      config.instance_variable_set(:@targets, { production: production, staging: staging })

      allow(production).to receive(:run!)
      allow(production).to receive(:copy_file)

      expect(staging).to receive(:run!)
        .with(/bin\/rake db:load/)

      Bard::CLI::Data.new.sync(from: production, to: staging)
    end
  end

  describe "data DSL configuration" do
    it "allows configuring additional paths to sync" do
      config.data("public/uploads", "public/system")

      expect(config.data_paths).to include("public/uploads")
      expect(config.data_paths).to include("public/system")
    end

    it "syncs configured data paths" do
      config.data("public/uploads", "public/system")
      config.instance_variable_set(:@targets, { production: production, staging: staging })

      allow(production).to receive(:run!)
      allow(production).to receive(:copy_file)
      allow(staging).to receive(:run!)

      expect(production).to receive(:copy_dir)
        .with("public/uploads", to: staging)

      expect(production).to receive(:copy_dir)
        .with("public/system", to: staging)

      Bard::CLI::Data.new.sync(from: production, to: staging)
    end

    it "works without additional data paths" do
      config.instance_variable_set(:@targets, { production: production, staging: staging })

      allow(production).to receive(:run!)
      allow(production).to receive(:copy_file)
      allow(staging).to receive(:run!)

      # Should not call copy_dir if no data paths configured
      expect(production).not_to receive(:copy_dir)

      Bard::CLI::Data.new.sync(from: production, to: staging)
    end
  end

  describe "safety warnings" do
    it "warns when pushing to production" do
      config.instance_variable_set(:@targets, { production: production, staging: staging })

      allow(staging).to receive(:run!)
      allow(staging).to receive(:copy_file)
      allow(production).to receive(:run!)

      expect { Bard::CLI::Data.new.sync(from: staging, to: production) }
        .to output(/WARNING.*production/).to_stdout
    end

    it "requires confirmation with full production URL" do
      config.instance_variable_set(:@targets, { production: production, staging: staging })
      production.ping("https://production.example.com")

      allow(staging).to receive(:run!)
      allow(staging).to receive(:copy_file)
      allow(production).to receive(:run!)

      expect { Bard::CLI::Data.new.sync(from: staging, to: production) }
        .to raise_error(/Please confirm by typing.*production.example.com/)
    end
  end
end
