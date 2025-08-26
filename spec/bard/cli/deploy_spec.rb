require "spec_helper"
require "bard/cli"
require "bard/cli/deploy"
require "thor"

class TestDeployCLI < Thor
  include Bard::CLI::Deploy

  attr_reader :config, :options

  def initialize
    super
    @config = {}
    @options = {}
  end

  def project_name
    "test_project"
  end
end

describe Bard::CLI::Deploy do
  let(:production_server) { double("production", run!: true, github_pages: false, path: "/var/www/test_project") }
  let(:config) { { production: production_server } }
  let(:cli) { TestDeployCLI.new }

  before do
    allow(cli).to receive(:config).and_return(config)
    allow(cli).to receive(:options).and_return({ target: "production" })
    allow(cli).to receive(:puts)
    allow(cli).to receive(:exit)
    allow(cli).to receive(:run!)
    allow(cli).to receive(:invoke)
    allow(cli).to receive(:ping)
    allow(cli).to receive(:green).and_return("")
    allow(cli).to receive(:red).and_return("")
    allow(cli).to receive(:yellow).and_return("")
    allow(Bard::Git).to receive(:current_branch).and_return("feature-branch")
    allow(Bard::Git).to receive(:up_to_date_with_remote?).and_return(true)
    allow(Bard::Git).to receive(:fast_forward_merge?).and_return(true)
    allow(cli).to receive(:`).and_return("")
  end

  describe "#deploy" do
    it "should have a deploy command" do
      expect(cli).to respond_to(:deploy)
    end

    context "when on master branch" do
      before do
        allow(Bard::Git).to receive(:current_branch).and_return("master")
        allow(cli).to receive(:options).and_return({ target: "production" })
      end

      context "when up to date with remote" do
        it "skips push and runs CI then deploys" do
          allow(Bard::Git).to receive(:up_to_date_with_remote?).and_return(true)

          expect(cli).not_to receive(:run!).with(/git push/)
          expect(cli).to receive(:invoke).with(:ci, ["master"], {})
          expect(production_server).to receive(:run!).with("git pull origin master && bin/setup")
          expect(cli).to receive(:puts) # "Deploy Succeeded"
          expect(cli).to receive(:ping).with(:production)

          cli.deploy
        end
      end

      context "when not up to date with remote" do
        it "pushes master then runs CI and deploys" do
          allow(Bard::Git).to receive(:up_to_date_with_remote?).and_return(false)

          expect(cli).to receive(:run!).with("git push origin master:master")
          expect(cli).to receive(:invoke).with(:ci, ["master"], {})
          expect(production_server).to receive(:run!).with("git pull origin master && bin/setup")

          cli.deploy
        end
      end

      context "with skip-ci option" do
        it "skips CI step" do
          allow(cli).to receive(:options).and_return({ "skip-ci" => true, target: "production" })

          expect(cli).not_to receive(:invoke).with(:ci, anything, anything)
          expect(production_server).to receive(:run!).with("git pull origin master && bin/setup")

          cli.deploy
        end
      end
    end

    context "when on feature branch" do
      before do
        allow(cli).to receive(:options).and_return({ target: "production" })
      end

      context "with fast-forward merge possible" do
        it "fetches master, pushes branch, runs CI, merges to master, and deploys" do
          expect(cli).to receive(:run!).with("git fetch origin")
          expect(cli).to receive(:run!).with("git fetch origin master:master").twice
          expect(cli).to receive(:run!).with("git push -f origin feature-branch:feature-branch")
          expect(cli).to receive(:invoke).with(:ci, ["feature-branch"], {})
          expect(cli).to receive(:run!).with("git push origin feature-branch:master")
          expect(production_server).to receive(:run!).with("git pull origin master && bin/setup")

          cli.deploy
        end

        it "deletes the feature branch after successful deploy" do
          expect(cli).to receive(:puts).with("Deleting branch: feature-branch")
          expect(cli).to receive(:run!).with("git push --delete origin feature-branch")
          expect(cli).to receive(:run!).with("git checkout master")
          expect(cli).to receive(:run!).with("git branch -D feature-branch")

          cli.deploy
        end
      end

      context "when rebase is needed" do
        it "attempts rebase before proceeding" do
          allow(Bard::Git).to receive(:fast_forward_merge?).and_return(false)

          expect(cli).to receive(:puts).with("The master branch has advanced. Attempting rebase...")
          expect(cli).to receive(:run!).with("git rebase origin/master")
          expect(cli).to receive(:run!).with("git push -f origin feature-branch:feature-branch")

          cli.deploy
        end
      end
    end

    context "with github remote" do
      it "pushes to github remote" do
        allow(cli).to receive(:`).with("git remote").and_return("origin\ngithub\n")

        expect(cli).to receive(:run!).with("git push github")

        cli.deploy
      end
    end

    context "with clone option" do
      it "clones repository and sets up application" do
        allow(cli).to receive(:options).and_return({ clone: true, target: "production" })

        expect(production_server).to receive(:run!).with("git clone git@github.com:botandrosedesign/test_project /var/www/test_project", home: true)
        expect(cli).to receive(:invoke).with(:master_key, [], from: "local", to: :production)
        expect(production_server).to receive(:run!).with("bin/setup && bard setup")

        cli.deploy
      end
    end

    context "with github pages" do
      it "deploys to github pages" do
        allow(production_server).to receive(:github_pages).and_return(true)
        github_pages = double("github_pages")
        allow(Bard::GithubPages).to receive(:new).and_return(github_pages)

        expect(github_pages).to receive(:deploy).with(production_server)

        cli.deploy
      end
    end

    context "with custom deployment target" do
      let(:staging_server) { double("staging", run!: true, github_pages: false) }

      before do
        allow(config).to receive(:[]).with(:staging).and_return(staging_server)
        allow(cli).to receive(:options).and_return({ target: "staging" })
      end

      it "deploys to specified target" do
        expect(staging_server).to receive(:run!).with("git pull origin master && bin/setup")
        expect(cli).to receive(:ping).with(:staging)

        cli.deploy
      end
    end

    context "when command fails" do
      it "handles errors gracefully" do
        allow(cli).to receive(:run!).and_raise(Bard::Command::Error.new("Git push failed"))

        expect(cli).to receive(:puts).with(/Running command failed/)
        expect(cli).to receive(:exit).with(1)

        cli.deploy
      end
    end

    context "with local-ci option" do
      it "passes local-ci option to CI invocation" do
        allow(cli).to receive(:options).and_return({ "local-ci" => true, target: "production" })

        expect(cli).to receive(:invoke).with(:ci, ["feature-branch"], { "local-ci" => true })

        cli.deploy
      end
    end
  end
end