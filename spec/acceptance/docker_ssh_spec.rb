# Proof of Concept: Docker with SSH
#
# Pros: Lightweight, fast, portable, easy to debug
# Cons: Requires Docker daemon
#
# Setup:
#   docker build -t bard-test-server spec/acceptance/docker
#   docker run -d --name bard-test-ssh -p 2222:22 bard-test-server

require 'spec_helper'
require 'open3'

RSpec.describe "Bard run command with Docker SSH server", type: :acceptance do
  before(:all) do
    # Build the test image
    system("docker build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker")

    # Start container
    system("docker run -d --name bard-test-ssh -p 2222:22 bard-test-server")

    # Wait for SSH to be ready
    30.times do
      break if system("ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'echo ready' 2>/dev/null")
      sleep 0.5
    end

    # Create test project directory on the server
    system("ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'mkdir -p testproject'")

    # Create test bard.rb config
    File.write("tmp/test_bard.rb", <<~RUBY)
      server :production do
        ssh "deploy@localhost:2222"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end
    RUBY
  end

  after(:all) do
    system("docker rm -f bard-test-ssh 2>/dev/null")
    FileUtils.rm_f("tmp/test_bard.rb")
  end

  it "runs ls command on remote server" do
    # Create a test file on the server
    system("ssh -o StrictHostKeyChecking=no -p 2222 deploy@localhost -i spec/acceptance/docker/test_key 'touch testproject/test.txt'")

    # Run bard command
    Dir.chdir("tmp") do
      output, status = Open3.capture2e("bard run ls", chdir: Dir.pwd)

      expect(status.success?).to be true
      expect(output).to include("test.txt")
    end
  end
end
