require "bard/deprecation"
require "bard/config"
require "bard/server"

describe Bard::Deprecation do
  before do
    Bard::Deprecation.reset!
  end

  describe ".warn" do
    it "outputs a deprecation warning to stderr" do
      expect {
        Bard::Deprecation.warn "test message"
      }.to output(/\[DEPRECATION\] test message/).to_stderr
    end

    it "includes the callsite location" do
      output = capture_stderr { Bard::Deprecation.warn "test message" }
      expect(output).to match(/called from.*deprecation_spec\.rb/)
    end

    it "only warns once per callsite" do
      output = capture_stderr do
        3.times { Bard::Deprecation.warn "repeated message" }
      end
      expect(output.scan(/\[DEPRECATION\]/).count).to eq 1
    end

    it "warns separately for different callsites" do
      output = capture_stderr do
        Bard::Deprecation.warn "message 1"
        Bard::Deprecation.warn "message 2"
      end
      expect(output.scan(/\[DEPRECATION\]/).count).to eq 2
    end
  end

  describe ".reset!" do
    it "clears the warning cache" do
      capture_stderr { Bard::Deprecation.warn "test" }
      Bard::Deprecation.reset!
      output = capture_stderr { Bard::Deprecation.warn "test" }
      expect(output).to include("[DEPRECATION]")
    end
  end

  def capture_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end
end

describe "Deprecation warnings" do
  before do
    Bard::Deprecation.reset!
  end

  def capture_stderr
    original_stderr = $stderr
    $stderr = StringIO.new
    yield
    $stderr.string
  ensure
    $stderr = original_stderr
  end

  describe "Config#server" do
    it "warns when using server instead of target" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          server :production do
            ssh "user@host:22"
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("`server` is deprecated")
      expect(output).to include("use `target` instead")
    end

    it "does not warn when using target" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
          end
        SOURCE
      end
      expect(output).not_to include("[DEPRECATION]")
    end
  end

  describe "Server SSH options" do
    it "warns when using separate path method" do
      output = capture_stderr do
        Bard::Server.define("test", :production) do
          ssh "user@host:22"
          path "/app"
        end
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate SSH options are deprecated")
    end

    it "warns when using separate gateway method" do
      output = capture_stderr do
        Bard::Server.define("test", :production) do
          ssh "user@host:22"
          gateway "bastion@host:22"
        end
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate SSH options are deprecated")
    end

    it "warns when using separate ssh_key method" do
      output = capture_stderr do
        Bard::Server.define("test", :production) do
          ssh "user@host:22"
          ssh_key "~/.ssh/id_rsa"
        end
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate SSH options are deprecated")
    end

    it "warns when using separate env method" do
      output = capture_stderr do
        Bard::Server.define("test", :production) do
          ssh "user@host:22"
          env "RAILS_ENV=production"
        end
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate SSH options are deprecated")
    end
  end

  describe "Server strategy configuration" do
    it "warns when using strategy method" do
      output = capture_stderr do
        Bard::Server.define("test", :production) do
          ssh "user@host:22"
          strategy :custom
        end
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("`strategy` is deprecated")
    end

    it "warns when using option method" do
      output = capture_stderr do
        Bard::Server.define("test", :production) do
          ssh "user@host:22"
          option :run_tests, true
        end
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("`option` is deprecated")
    end

    it "stores strategy name for backward compatibility" do
      server = nil
      capture_stderr do
        server = Bard::Server.define("test", :production) do
          ssh "user@host:22"
          strategy :jets
        end
      end
      expect(server.strategy_name).to eq :jets
    end

    it "stores strategy options for backward compatibility" do
      server = nil
      capture_stderr do
        server = Bard::Server.define("test", :production) do
          ssh "user@host:22"
          option :run_tests, true
          option :verbose, false
        end
      end
      expect(server.strategy_options).to eq({ run_tests: true, verbose: false })
    end
  end

  describe "Target (new API)" do
    it "does not warn when using hash options with ssh" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22", path: "/app", gateway: "bastion@host:22"
          end
        SOURCE
      end
      expect(output).not_to include("[DEPRECATION]")
    end

    it "warns when using separate path method" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
            path "/app"
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate `path` call is deprecated")
    end

    it "warns when using separate gateway method" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
            gateway "bastion@host:22"
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate `gateway` call is deprecated")
    end

    it "warns when using separate ssh_key method" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
            ssh_key "~/.ssh/id_rsa"
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate `ssh_key` call is deprecated")
    end

    it "warns when using separate env method" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
            env "RAILS_ENV=production"
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("Separate `env` call is deprecated")
    end

    it "warns when using strategy method" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
            strategy :ssh
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("`strategy` is deprecated")
    end

    it "warns when using option method" do
      output = capture_stderr do
        Bard::Config.new("test", source: <<~SOURCE)
          target :production do
            ssh "user@host:22"
            strategy :ssh
            option :verbose, true
          end
        SOURCE
      end
      expect(output).to include("[DEPRECATION]")
      expect(output).to include("`option` is deprecated")
    end
  end
end
