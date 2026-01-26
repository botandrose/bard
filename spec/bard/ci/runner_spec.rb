require "bard/ci/runner"

RSpec.describe Bard::CI::Runner do
  describe ".runners" do
    it "is a hash registry" do
      expect(described_class.runners).to be_a(Hash)
    end
  end

  describe ".[]" do
    before do
      require "bard/ci/local"
      require "bard/ci/github_actions"
    end

    it "looks up runners by name" do
      expect(described_class[:local]).to eq Bard::CI::Local
      expect(described_class[:github_actions]).to eq Bard::CI::GithubActions
    end

    it "returns nil for unknown runners" do
      expect(described_class[:nonexistent]).to be_nil
    end
  end

  describe ".default" do
    it "returns the last registered runner" do
      # Whatever was registered last in the current test run
      expect(described_class.default).to be_a(Class)
      expect(described_class.default.ancestors).to include(Bard::CI::Runner)
    end
  end

  describe "auto-registration via inherited" do
    it "registers subclasses automatically" do
      eval <<-RUBY
        module Bard
          class CI
            class SpecTestRunner < Runner
            end
          end
        end
      RUBY

      expect(described_class[:spec_test_runner]).to eq Bard::CI::SpecTestRunner
    end

    it "newly registered runner becomes the default" do
      eval <<-RUBY
        module Bard
          class CI
            class AnotherTestRunner < Runner
            end
          end
        end
      RUBY

      expect(described_class.default).to eq Bard::CI::AnotherTestRunner
    end
  end
end
