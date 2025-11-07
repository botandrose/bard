# Proof of Concept: systemd-nspawn
#
# Pros: Minimal overhead, built into systemd, very fast
# Cons: Less isolation, requires root, more manual setup
#
# Setup:
#   debootstrap --variant=minbase jammy /var/lib/machines/bard-test

require 'spec_helper'
require 'open3'

RSpec.describe "Bard run command with systemd-nspawn", type: :acceptance do
  before(:all) do
    # This requires root and is more complex
    # Shown here for completeness but may not be practical for most use cases

    machine_path = "/var/lib/machines/bard-test-nspawn"

    # Create base system (requires root)
    unless File.exist?(machine_path)
      system("sudo debootstrap --variant=minbase jammy #{machine_path}")
    end

    # Boot the container
    system("sudo systemd-nspawn --boot -D #{machine_path} --machine=bard-test-nspawn &")
    sleep 5 # Wait for boot

    # Install SSH in the container
    system("sudo systemd-run --machine=bard-test-nspawn --wait apt-get update -qq")
    system("sudo systemd-run --machine=bard-test-nspawn --wait apt-get install -y -qq openssh-server")

    # Create deploy user
    system("sudo systemd-run --machine=bard-test-nspawn --wait useradd -m -s /bin/bash deploy")

    # Setup SSH key
    system("sudo mkdir -p #{machine_path}/home/deploy/.ssh")
    system("sudo cp spec/acceptance/docker/test_key.pub #{machine_path}/home/deploy/.ssh/authorized_keys")
    system("sudo chown -R 1000:1000 #{machine_path}/home/deploy/.ssh") # Assuming deploy UID is 1000

    # Start SSH
    system("sudo systemd-run --machine=bard-test-nspawn --wait systemctl start ssh")

    # Get container IP
    @container_ip = `sudo machinectl show bard-test-nspawn -p IPAddress --value`.strip

    # Create project directory
    system("sudo systemd-run --machine=bard-test-nspawn --wait su - deploy -c 'mkdir -p testproject'")

    File.write("tmp/test_bard_nspawn.rb", <<~RUBY)
      server :production do
        ssh "deploy@#{@container_ip}"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end
    RUBY
  end

  after(:all) do
    system("sudo machinectl terminate bard-test-nspawn 2>/dev/null")
    # Optionally remove: sudo rm -rf /var/lib/machines/bard-test-nspawn
    FileUtils.rm_f("tmp/test_bard_nspawn.rb")
  end

  it "runs ls command on systemd-nspawn container" do
    system("sudo systemd-run --machine=bard-test-nspawn --wait su - deploy -c 'touch testproject/nspawn-test.txt'")

    Dir.chdir("tmp") do
      File.write("bard.rb", File.read("test_bard_nspawn.rb"))
      output, status = Open3.capture2e("bard run ls")
      File.delete("bard.rb")

      expect(status.success?).to be true
      expect(output).to include("nspawn-test.txt")
    end
  end

  # Benefits of systemd-nspawn:
  # - Extremely lightweight
  # - No daemon required
  # - Built into systemd
  # - Can use machinectl for management
  #
  # Drawbacks:
  # - Requires root for most operations
  # - Less isolation than other options
  # - More manual setup
  # - Not as portable
end
