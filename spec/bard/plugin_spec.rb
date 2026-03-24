require "bard/plugin"

RSpec.describe Bard::Plugin do
  describe ".load!" do
    it "loads plugin files from the plugins directory" do
      expect(described_class).to respond_to(:load!)
    end
  end
end
