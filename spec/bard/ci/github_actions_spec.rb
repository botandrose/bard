require "spec_helper"
require "bard/ci/github_actions"

BASE_URL = "https://api.github.com/repos/botandrosedesign/metrc"

RSpec.shared_context "github actions stubs" do
  let(:run_id) { 123 }
  let(:job_id) { 456 }
  let(:started_at) { "2024-01-15T10:00:00Z" }
  let(:completed_at) { "2024-01-15T10:01:30Z" }
  let(:sha) { "abc123" }

  let(:run_json) do
    {
      "id" => run_id,
      "status" => "completed",
      "conclusion" => "success",
      "head_branch" => "master",
      "head_sha" => sha,
      "run_started_at" => started_at,
      "updated_at" => completed_at,
    }
  end

  let(:job_json) do
    {
      "id" => job_id,
      "started_at" => started_at,
      "completed_at" => completed_at,
    }
  end

  before do
    allow(Bard::Secrets).to receive(:fetch).with("github-apikey").and_return("test-key")
  end
end

describe Bard::CI::GithubActions::API do
  include_context "github actions stubs"

  subject { described_class.new("metrc") }

  describe "#last_successful_run" do
    before do
      stub_request(:get, "#{BASE_URL}/actions/runs")
        .with(query: hash_including("status" => "success"))
        .to_return(
          headers: { "Content-Type" => "application/json" },
          body: JSON.dump("workflow_runs" => [run_json]),
        )

      stub_request(:get, "#{BASE_URL}/actions/runs/#{run_id}/jobs")
        .with(query: hash_including("filter" => "latest"))
        .to_return(
          headers: { "Content-Type" => "application/json" },
          body: JSON.dump("jobs" => [job_json]),
        )
    end

    it "has #time_elapsed" do
      run = subject.last_successful_run
      expect(run.time_elapsed).to eq 90
    end

    it "has #console" do
      stub_request(:get, "#{BASE_URL}/actions/jobs/#{job_id}/logs")
        .to_return(
          headers: { "Content-Type" => "text/plain" },
          body: "build log output here",
        )

      expect(subject.last_successful_run.console).to eq "build log output here"
    end
  end

  describe "#create_run!" do
    it "returns a run" do
      stub_request(:post, "#{BASE_URL}/actions/workflows/ci.yml/dispatches")
        .to_return(status: 204, body: "")

      allow(subject).to receive(:`).with("git rev-parse master").and_return("#{sha}\n")

      stub_request(:get, "#{BASE_URL}/actions/runs")
        .with(query: hash_including("head_sha" => sha))
        .to_return(
          headers: { "Content-Type" => "application/json" },
          body: JSON.dump("workflow_runs" => [run_json]),
        )

      run = subject.create_run!("master")
      expect(run).to be_a Bard::CI::GithubActions::Run
      expect(run.id).to eq run_id
    end
  end
end

describe Bard::CI::GithubActions do
  include_context "github actions stubs"

  subject { described_class.new("metrc", "master", sha) }

  it "returns true on successful run" do
    stub_request(:post, "#{BASE_URL}/actions/workflows/ci.yml/dispatches")
      .to_return(status: 204, body: "")

    allow_any_instance_of(Bard::CI::GithubActions::API)
      .to receive(:`).with("git rev-parse master").and_return("#{sha}\n")

    stub_request(:get, "#{BASE_URL}/actions/runs")
      .with(query: hash_including("head_sha" => sha))
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: JSON.dump("workflow_runs" => [run_json]),
      )

    stub_request(:get, "#{BASE_URL}/actions/runs")
      .with(query: hash_including("status" => "success"))
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: JSON.dump("workflow_runs" => [run_json]),
      )

    stub_request(:get, "#{BASE_URL}/actions/runs/#{run_id}/jobs")
      .with(query: hash_including("filter" => "latest"))
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: JSON.dump("jobs" => [job_json]),
      )

    stub_request(:get, "#{BASE_URL}/actions/runs/#{run_id}")
      .to_return(
        headers: { "Content-Type" => "application/json" },
        body: JSON.dump(run_json),
      )

    expect(subject.run { }).to eq true
  end
end
