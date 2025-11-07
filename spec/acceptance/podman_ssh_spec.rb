# Proof of Concept: Podman with SSH (rootless)
#
# Pros: No sudo required, rootless, Docker-compatible, daemonless
# Cons: Slightly different behavior from Docker in edge cases
#
# Setup: Same as Docker but with podman commands
# Note: Podman can use Dockerfiles and most docker commands directly

require 'spec_helper'
require 'open3'

RSpec.describe "Bard run command with Podman SSH server", type: :acceptance do
  before(:all) do
    # Build the test image with podman
    system("podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker")

    # Start container (rootless, no sudo needed!)
    system("podman run -d --name bard-test-podman -p 2223:22 bard-test-server")

    # Wait for SSH to be ready
    30.times do
      break if system("ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'echo ready' 2>/dev/null")
      sleep 0.5
    end

    # Create test project directory
    system("ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'mkdir -p testproject'")

    # Create test bard.rb config
    File.write("tmp/test_bard_podman.rb", <<~RUBY)
      server :production do
        ssh "deploy@localhost:2223"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end
    RUBY
  end

  after(:all) do
    system("podman rm -f bard-test-podman 2>/dev/null")
    FileUtils.rm_f("tmp/test_bard_podman.rb")
  end

  it "runs ls command on remote server" do
    # Create a test file
    system("ssh -o StrictHostKeyChecking=no -p 2223 deploy@localhost -i spec/acceptance/docker/test_key 'touch testproject/podman-test.txt'")

    # Run bard command
    Dir.chdir("tmp") do
      File.write("bard.rb", File.read("test_bard_podman.rb"))
      output, status = Open3.capture2e("bard run ls")
      File.delete("bard.rb")

      expect(status.success?).to be true
      expect(output).to include("podman-test.txt")
    end
  end
end
