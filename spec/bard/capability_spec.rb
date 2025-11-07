require "spec_helper"
require "bard/target"

describe "Capability System" do
  let(:config) { double("config", project_name: "testapp") }
  let(:target) { Bard::Target.new(:production, config) }

  describe "#enable_capability" do
    it "enables a capability on the target" do
      target.enable_capability(:ssh)
      expect(target.has_capability?(:ssh)).to be true
    end

    it "can enable multiple capabilities" do
      target.enable_capability(:ssh)
      target.enable_capability(:ping)
      expect(target.has_capability?(:ssh)).to be true
      expect(target.has_capability?(:ping)).to be true
    end
  end

  describe "#has_capability?" do
    it "returns false for capabilities that are not enabled" do
      expect(target.has_capability?(:ssh)).to be false
    end

    it "returns true for capabilities that are enabled" do
      target.enable_capability(:ssh)
      expect(target.has_capability?(:ssh)).to be true
    end
  end

  describe "#require_capability!" do
    it "does not raise an error if capability is enabled" do
      target.enable_capability(:ssh)
      expect { target.require_capability!(:ssh) }.not_to raise_error
    end

    it "raises an error if capability is not enabled" do
      expect { target.require_capability!(:ssh) }
        .to raise_error(/SSH not configured for this target/)
    end

    it "provides custom error message for ping capability" do
      expect { target.require_capability!(:ping) }
        .to raise_error(/Ping URL not configured for this target/)
    end

    it "provides generic error message for unknown capabilities" do
      expect { target.require_capability!(:unknown) }
        .to raise_error(/unknown capability not configured for this target/)
    end
  end

  describe "capability dependency checking" do
    context "SSH-dependent methods" do
      it "run! requires SSH capability" do
        expect { target.run!("ls") }
          .to raise_error(/SSH not configured/)
      end

      it "run requires SSH capability" do
        expect { target.run("ls") }
          .to raise_error(/SSH not configured/)
      end

      it "exec! requires SSH capability" do
        expect { target.exec!("ls") }
          .to raise_error(/SSH not configured/)
      end

      it "copy_file requires SSH capability" do
        other_target = Bard::Target.new(:staging, config)
        expect { target.copy_file("test.txt", to: other_target) }
          .to raise_error(/SSH not configured/)
      end

      it "copy_dir requires SSH capability" do
        other_target = Bard::Target.new(:staging, config)
        expect { target.copy_dir("test/", to: other_target) }
          .to raise_error(/SSH not configured/)
      end
    end

    context "Ping-dependent methods" do
      it "ping! requires ping capability" do
        expect { target.ping! }
          .to raise_error(/Ping URL not configured/)
      end

      it "open requires ping capability" do
        expect { target.open }
          .to raise_error(/Ping URL not configured/)
      end
    end
  end
end
