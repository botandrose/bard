require "spec_helper"
require "bard/github"

describe Bard::Github do
  let(:github) { Bard::Github.new("test-project") }

  before do
    allow(github).to receive(:`).with("git ls-remote -t git@github.com:botandrosedesign/secrets").and_return("github-apikey|12345")
  end

  describe "#get" do
    it "should make a GET request to the GitHub API" do
      stub_request(:get, "https://api.github.com/repos/botandrosedesign/test-project/path").to_return(body: "{}")
      github.get("path")
    end
  end

  describe "#post" do
    it "should make a POST request to the GitHub API" do
      stub_request(:post, "https://api.github.com/repos/botandrosedesign/test-project/path").with(body: "{\"foo\":\"bar\"}").to_return(body: "{}")
      github.post("path", { foo: "bar" })
    end
  end

  describe "#put" do
    it "should make a PUT request to the GitHub API" do
      stub_request(:put, "https://api.github.com/repos/botandrosedesign/test-project/path").with(body: "{\"foo\":\"bar\"}").to_return(body: "{}")
      github.put("path", { foo: "bar" })
    end
  end

  describe "#patch" do
    it "should make a PATCH request to the GitHub API" do
      stub_request(:patch, "https://api.github.com/repos/botandrosedesign/test-project/path").with(body: "{\"foo\":\"bar\"}").to_return(body: "{}")
      github.patch("path", { foo: "bar" })
    end
  end

  describe "#delete" do
    it "should make a DELETE request to the GitHub API" do
      stub_request(:delete, "https://api.github.com/repos/botandrosedesign/test-project").with(body: "{\"foo\":\"bar\"}").to_return(body: "{}")
      github.delete(nil, { foo: "bar" })
    end
  end
end
