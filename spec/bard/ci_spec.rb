require "bard/ci"

describe Bard::CI do
  subject { described_class.new("tracker", "master") }

  describe "#exists?"
  describe "#status"
  describe "#console"
  describe "#run"
end
