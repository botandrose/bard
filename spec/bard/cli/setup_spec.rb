require "spec_helper"
require "bard/cli"

describe "bard setup" do
  let(:cli) { Bard::CLI.new }

  before do
    allow(cli).to receive(:project_name).and_return("test_project")
    allow(Dir).to receive(:pwd).and_return("/home/user/project")
    allow(File).to receive(:exist?).and_return(false)
    allow(cli).to receive(:system)
  end

  describe "#setup" do
    before { allow(cli).to receive(:nginx_server_name).and_return("test_project.localhost") }

    it "should have a setup command" do
      expect(cli).to respond_to(:setup)
    end

    context "in production" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("production")
      end

      it "creates an nginx reverse proxy config" do
        expect(cli).to receive(:system).with(/sudo tee \/etc\/nginx\/sites-available\/test_project.*proxy_pass http:\/\/puma/m)
        expect(cli).to receive(:system).with(/sudo ln -sf/)
        expect(cli).to receive(:system).with("sudo service nginx restart")

        cli.setup
      end
    end

    context "in staging" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("staging")
      end

      it "creates a Passenger nginx config, not a puma reverse proxy" do
        expect(cli).to receive(:system).with(/sudo tee \/etc\/nginx\/sites-available\/test_project.*include \/etc\/nginx\/snippets\/common\.conf/m)
        expect(cli).not_to receive(:system).with(/proxy_pass http:\/\/puma/m)
        expect(cli).to receive(:system).with(/sudo ln -sf/)
        expect(cli).to receive(:system).with("sudo service nginx restart")

        cli.setup
      end
    end

    context "in development" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("development")
      end

      it "creates an nginx config that includes the shared dev snippet" do
        expect(cli).to receive(:system).with(/sudo tee \/etc\/nginx\/sites-available\/test_project.*include \/etc\/nginx\/snippets\/common\.conf/m)
        expect(cli).to receive(:system).with(/sudo ln -sf/)
        expect(cli).to receive(:system).with("sudo service nginx restart")

        cli.setup
      end
    end
  end

  describe "#nginx_server_name" do
    let(:production_server) { double("production", url: "https://example.com") }

    before do
      allow(cli).to receive(:config).and_return({ production: production_server })
    end

    context "when RAILS_ENV is production" do
      before { allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("production") }

      it "returns production server names with wildcard" do
        expect(cli.nginx_server_name).to eq("*.example.com _")
      end
    end

    context "when RAILS_ENV is staging" do
      before { allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("staging") }

      it "returns staging server name" do
        expect(cli.nginx_server_name).to eq("test_project.botandrose.com")
      end
    end

    context "when RAILS_ENV is development" do
      before { allow(ENV).to receive(:[]).with("RAILS_ENV").and_return("development") }

      it "returns localhost server name" do
        expect(cli.nginx_server_name).to eq("test_project.localhost")
      end
    end
  end
end
