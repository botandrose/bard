# Acceptance test for Bard using Podman + TestContainers
#
# This test validates end-to-end functionality of `bard run ls` by:
# 1. Starting an SSH server container using TestContainers
# 2. Configuring Bard to connect to it
# 3. Running bard commands against the container
# 4. Automatically cleaning up when done
#
# Prerequisites:
# - gem install testcontainers
# - podman installed
# - podman socket running (systemctl --user start podman.socket)
# - Set DOCKER_HOST to podman socket

require 'spec_helper'
require 'testcontainers'
require 'open3'

RSpec.describe "Bard acceptance test with Podman + TestContainers", type: :acceptance do
  # Disable WebMock for acceptance tests - we need real HTTP connections to Podman
  before(:all) do
    WebMock.allow_net_connect!
  end

  after(:all) do
    WebMock.disable_net_connect!
  end
  # Configure TestContainers to use Podman
  before(:all) do
    # Set up podman socket for TestContainers
    podman_socket = "/run/user/#{Process.uid}/podman/podman.sock"

    # Start podman socket if not running
    unless File.exist?(podman_socket)
      system("systemctl --user start podman.socket 2>/dev/null || podman system service --time=0 unix://#{podman_socket} &")
      sleep 2
    end

    # Configure TestContainers to use podman
    ENV['DOCKER_HOST'] = "unix://#{podman_socket}"

    # Ensure SSH key has correct permissions
    system("chmod 600 spec/acceptance/docker/test_key")

    # Check if we can pull images
    unless system("podman pull ubuntu:22.04 >/dev/null 2>&1")
      skip "Cannot pull images in this environment. Run in a network-enabled environment."
    end

    # Build the test image
    unless system("podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker 2>&1")
      skip "Failed to build test image"
    end
  end

  # TestContainers will automatically manage this container
  let(:container) do
    Testcontainers::DockerContainer.new("localhost/bard-test-server:latest")
      .with_exposed_port(22)
      .with_name("bard-test-#{SecureRandom.hex(4)}")
      .start
  end

  let(:ssh_port) { container.mapped_port(22) }

  before(:each) do
    # Ensure container is started
    container

    # Wait for SSH to be ready
    30.times do
      break if system("ssh -o StrictHostKeyChecking=no -o ConnectTimeout=1 -p #{ssh_port} deploy@localhost -i spec/acceptance/docker/test_key 'echo ready' 2>/dev/null")
      sleep 0.5
    end

    # Create test project directory
    system("ssh -o StrictHostKeyChecking=no -p #{ssh_port} deploy@localhost -i spec/acceptance/docker/test_key 'mkdir -p testproject'")

    # Create bard config for this container
    @bard_config_path = "tmp/test_bard_#{SecureRandom.hex(4)}.rb"
    FileUtils.mkdir_p("tmp")
    ssh_key_path = File.expand_path("spec/acceptance/docker/test_key")
    File.write(@bard_config_path, <<~RUBY)
      server :production do
        ssh "deploy@localhost:#{ssh_port}"
        path "testproject"
        ssh_key "#{ssh_key_path}"
        ping false
      end
    RUBY
  end

  after(:each) do
    # Clean up bard config
    FileUtils.rm_f(@bard_config_path) if @bard_config_path

    # TestContainers will automatically stop and remove the container
    container.stop if container
    container.remove if container
  end

  it "runs ls command via bard run" do
    # Create a test file in the container
    result = system("ssh -o StrictHostKeyChecking=no -p #{ssh_port} deploy@localhost -i spec/acceptance/docker/test_key 'touch testproject/test-file.txt'")
    expect(result).to be true

    # Run bard command
    Dir.chdir("tmp") do
      # Copy config to bard.rb
      FileUtils.cp("../#{@bard_config_path}", "bard.rb")

      output, status = Open3.capture2e("bard run ls")

      # Clean up
      FileUtils.rm_f("bard.rb")

      # Verify the command succeeded
      expect(status).to be_success, "bard run failed with output: #{output}"
      expect(output).to include("test-file.txt")
    end
  end

  it "runs multiple commands in isolated containers" do
    # Each test gets its own container automatically!
    result = system("ssh -o StrictHostKeyChecking=no -p #{ssh_port} deploy@localhost -i spec/acceptance/docker/test_key 'echo content > testproject/another-file.txt'")
    expect(result).to be true

    Dir.chdir("tmp") do
      FileUtils.cp("../#{@bard_config_path}", "bard.rb")
      output, status = Open3.capture2e("bard run 'cat another-file.txt'")
      FileUtils.rm_f("bard.rb")

      expect(status).to be_success, "bard run failed with output: #{output}"
      expect(output).to include("content")
    end
  end
end
