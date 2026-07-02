require "spec_helper"
require "bard/plugins/deploy/strategy"
require "bard/plugins/deploy/ssh_strategy"

describe Bard::DeployStrategy::SSH do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) do
    t = Bard::Target.new(:production, config)
    t.ssh("deploy@example.com:22", path: "/app")
    t
  end
  let(:strategy) { described_class.new(target) }

  describe "#deploy" do
    it "requires SSH capability" do
      target_without_ssh = Bard::Target.new(:local, config)
      strategy_without_ssh = described_class.new(target_without_ssh)

      expect { strategy_without_ssh.deploy }
        .to raise_error(/ssh capability not configured/)
    end

    it "runs git pull on remote server" do
      expect(target).to receive(:run!)
        .with("git pull --ff-only origin master")

      allow(target).to receive(:run!).with(/bin\/setup/)

      strategy.deploy
    end

    it "runs bin/setup on remote server" do
      allow(target).to receive(:run!).with(/git pull/)

      expect(target).to receive(:run!)
        .with(/bin\/setup/)

      strategy.deploy
    end

    it "pulls the given branch when one is specified" do
      expect(target).to receive(:run!)
        .with("git pull --ff-only origin main")

      allow(target).to receive(:run!).with(/bin\/setup/)

      strategy.deploy(branch: "main")
    end

    context "with force: true" do
      it "force-checks-out the given branch on the remote server" do
        expect(target).to receive(:run!).with("git fetch origin feature-x").ordered
        expect(target).to receive(:run!).with("git checkout -f origin/feature-x").ordered

        allow(target).to receive(:run!).with(/bin\/setup/)

        strategy.deploy(branch: "feature-x", force: true)
      end
    end

    context "with clone" do
      let(:local_target) { double("local") }

      before do
        allow(config).to receive(:[]).with(:local).and_return(local_target)
        allow(Bard::Copy).to receive(:file)
      end

      it "clones the repository, defaulting to master" do
        expect(target).to receive(:run!)
          .with("git clone --branch master git@github.com:botandrosedesign/testapp /app", home: true)
        allow(target).to receive(:run!).with("bin/setup")
        allow(target).to receive(:run!).with("bard setup")

        strategy.deploy(clone: "testapp")
      end

      it "copies master key from local" do
        allow(target).to receive(:run!).with(/git clone/, home: true)
        expect(Bard::Copy).to receive(:file)
          .with("config/master.key", from: local_target, to: target)
        allow(target).to receive(:run!).with("bin/setup")
        allow(target).to receive(:run!).with("bard setup")

        strategy.deploy(clone: "testapp")
      end

      it "runs bin/setup and bard setup" do
        allow(target).to receive(:run!).with(/git clone/, home: true)
        expect(target).to receive(:run!).with("bin/setup")
        expect(target).to receive(:run!).with("bard setup")

        strategy.deploy(clone: "testapp")
      end

      it "does not run git pull" do
        allow(target).to receive(:run!).with(/git clone/, home: true)
        allow(target).to receive(:run!).with("bin/setup")
        allow(target).to receive(:run!).with("bard setup")

        expect(target).not_to receive(:run!).with(/git pull/)

        strategy.deploy(clone: "testapp")
      end

      it "clones the requested branch directly when provisioning from scratch" do
        allow(target).to receive(:run!).with("bin/setup")
        allow(target).to receive(:run!).with("bard setup")

        expect(target).to receive(:run!)
          .with("git clone --branch feature-x git@github.com:botandrosedesign/testapp /app", home: true)
        expect(target).not_to receive(:run!).with(/git fetch/)
        expect(target).not_to receive(:run!).with(/git checkout/)

        strategy.deploy(clone: "testapp", branch: "feature-x")
      end
    end
  end

  describe "auto-registration" do
    it "registers as :ssh strategy" do
      expect(Bard::DeployStrategy[:ssh]).to eq(described_class)
    end
  end

  describe "integration with target" do
    it "is the default strategy when SSH is configured" do
      require "bard/plugins/deploy"
      new_target = Bard::Target.new(:staging, config)
      new_target.ssh("deploy@staging.example.com:22")

      expect(new_target.deploy_strategy_instance).to be_a(described_class)
    end
  end
end
