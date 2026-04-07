require "spec_helper"
require "bard/target"
require "bard/plugins/ssh/target_methods"
require "bard/plugins/ping/target_methods"

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
      target.enable_capability(:url)
      expect(target.has_capability?(:ssh)).to be true
      expect(target.has_capability?(:url)).to be true
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
        .to raise_error(/ssh capability not configured for this target/)
    end
  end

  describe "capability dependency checking" do
    context "URL-dependent methods" do
      it "ping! requires url capability" do
        expect { target.ping! }
          .to raise_error(/url capability not configured/)
      end
    end
  end
end
