# Proof of Concept: TestContainers
#
# Pros: Programmatic lifecycle, automatic cleanup, waits for readiness
# Cons: Requires testcontainers gem, Docker daemon
#
# gem install testcontainers

require 'spec_helper'
require 'open3'

# Uncomment when testcontainers gem is installed
# require 'testcontainers'

RSpec.describe "Bard run command with TestContainers", type: :acceptance do
  # Example implementation - requires testcontainers gem

  let(:container) do
    # This would use testcontainers to manage the container lifecycle
    # Testcontainers::DockerContainer.new("bard-test-server")
    #   .with_exposed_port(22)
    #   .with_wait_strategy(Testcontainers::WaitStrategies::LogMessageWaitStrategy.new("Server listening"))
    #   .start

    # For now, manual setup:
    system("docker run -d --name bard-test-tc -p 2224:22 bard-test-server")
    sleep 2 # Wait for startup
  end

  before(:all) do
    system("docker build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker")
  end

  before(:each) do
    container # start it

    # Wait for SSH
    30.times do
      break if system("ssh -o StrictHostKeyChecking=no -p 2224 deploy@localhost -i spec/acceptance/docker/test_key 'echo ready' 2>/dev/null")
      sleep 0.5
    end

    system("ssh -o StrictHostKeyChecking=no -p 2224 deploy@localhost -i spec/acceptance/docker/test_key 'mkdir -p testproject'")

    File.write("tmp/test_bard_tc.rb", <<~RUBY)
      server :production do
        ssh "deploy@localhost:2224"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end
    RUBY
  end

  after(:each) do
    system("docker rm -f bard-test-tc 2>/dev/null")
    # With real testcontainers: container.stop (automatic cleanup)
  end

  it "runs ls command with automatic container lifecycle" do
    system("ssh -o StrictHostKeyChecking=no -p 2224 deploy@localhost -i spec/acceptance/docker/test_key 'touch testproject/tc-test.txt'")

    Dir.chdir("tmp") do
      File.write("bard.rb", File.read("test_bard_tc.rb"))
      output, status = Open3.capture2e("bard run ls")
      File.delete("bard.rb")

      expect(status.success?).to be true
      expect(output).to include("tc-test.txt")
    end
  end

  # Benefits of testcontainers:
  # - Automatic port mapping discovery
  # - Built-in wait strategies
  # - Automatic cleanup even on test failures
  # - Support for docker-compose
  # - Can pull images automatically
end
