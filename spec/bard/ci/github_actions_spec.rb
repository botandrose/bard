require "bard/ci/github_actions"

describe Bard::CLI::CI::GithubActions do
  subject { described_class.new("metrc", "master", "0966308e204b256fdcc11457eb53306d84884c60") }

  xit "works" do
    subject.run
  end
end

describe Bard::CLI::CI::GithubActions::API do
  subject { described_class.new("metrc") }

  describe "#last_successful_run" do
    xit "has #time_elapsed" do
      subject.last_successful_run.time_elapsed
    end

    xit "has #console" do
      subject.last_successful_run.console
    end
  end

  describe "#create_run!" do
    xit "returns a run" do
      subject.create_run! "master"
    end
  end
end

describe Bard::CLI::CI::GithubActions::Client do
  subject { described_class.new("metrc") }
end

