require "spec_helper"
require "bard/copy"

describe Bard::Copy do
  let(:local) { double("local", key: :local, has_capability?: false) }
  let(:production) { double("production", key: :production, has_capability?: true) }

  around do |example|
    original_handlers = Bard::Copy.instance_variable_get(:@handlers).dup
    example.run
    Bard::Copy.instance_variable_set(:@handlers, original_handlers)
  end

  describe "auto-registration" do
    it "registers handlers via inherited hook" do
      handler = Class.new(Bard::Copy) do
        def self.can_handle?(from, to) = true
        def file = "copied"
      end

      copy = handler.new("path", local, production, false)
      expect(copy.file).to eq("copied")
    end
  end

  describe ".file" do
    it "dispatches to the handler that can handle the pair" do
      Class.new(Bard::Copy) do
        def self.can_handle?(from, to) = true
        def file = "file_copied"
      end

      expect(Bard::Copy.file("db/data.sql.gz", from: local, to: production)).to eq("file_copied")
    end
  end

  describe ".dir" do
    it "dispatches to the handler that can handle the pair" do
      Class.new(Bard::Copy) do
        def self.can_handle?(from, to) = true
        def dir = "dir_copied"
      end

      expect(Bard::Copy.dir("storage/", from: local, to: production)).to eq("dir_copied")
    end
  end

  describe ".handler_for!" do
    it "raises when no handler matches" do
      expect {
        Bard::Copy.file("file", from: local, to: local)
      }.to raise_error(/No copy handler for local -> local/)
    end
  end

  describe "#initialize" do
    it "stores path, from, to, verbose" do
      handler = Class.new(Bard::Copy) do
        def self.can_handle?(from, to) = true
      end

      copy = handler.new("db/data.sql.gz", local, production, true)
      expect(copy.path).to eq("db/data.sql.gz")
      expect(copy.from).to eq(local)
      expect(copy.to).to eq(production)
      expect(copy.verbose).to eq(true)
    end
  end
end
