require "bard/ci/github_actions"

describe Bard::CLI::CI::GithubActions do
  subject { described_class.new("metrc", "master", "0966308e204b256fdcc11457eb53306d84884c60") }

  xit "works" do
    subject.run
  end
end

describe Bard::CLI::CI::GithubActions::API do
  subject { described_class.new("metrc") }

  it "works" do
    puts subject.last_successful_run.time_elapsed
  end

  it "works" do
    puts subject.last_successful_run.console
  end
end

