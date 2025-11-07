# Proof of Concept: LXD/LXC System Containers
#
# Pros: Full systemd, more VM-like, very fast, Linux-native
# Cons: Linux-only, requires LXD setup, different from production containers
#
# Setup:
#   sudo snap install lxd
#   sudo lxd init --auto
#   lxc launch ubuntu:22.04 bard-test

require 'spec_helper'
require 'open3'

RSpec.describe "Bard run command with LXD container", type: :acceptance do
  before(:all) do
    # Launch LXD container
    system("lxc launch ubuntu:22.04 bard-test-lxd -c security.nesting=true")

    # Wait for container to boot
    30.times do
      break if system("lxc exec bard-test-lxd -- systemctl is-system-running --wait 2>/dev/null")
      sleep 1
    end

    # Install SSH server
    system("lxc exec bard-test-lxd -- apt-get update -qq")
    system("lxc exec bard-test-lxd -- apt-get install -y -qq openssh-server")

    # Create deploy user
    system("lxc exec bard-test-lxd -- useradd -m -s /bin/bash deploy")
    system("lxc exec bard-test-lxd -- mkdir -p /home/deploy/.ssh")

    # Copy SSH key
    system("lxc file push spec/acceptance/docker/test_key.pub bard-test-lxd/home/deploy/.ssh/authorized_keys")
    system("lxc exec bard-test-lxd -- chown -R deploy:deploy /home/deploy/.ssh")
    system("lxc exec bard-test-lxd -- chmod 700 /home/deploy/.ssh")
    system("lxc exec bard-test-lxd -- chmod 600 /home/deploy/.ssh/authorized_keys")

    # Start SSH service
    system("lxc exec bard-test-lxd -- systemctl start ssh")

    # Get container IP
    @container_ip = `lxc list bard-test-lxd -c4 --format csv | cut -d' ' -f1`.strip

    # Create project directory
    system("lxc exec bard-test-lxd -- su - deploy -c 'mkdir -p testproject'")

    # Create test bard.rb config
    File.write("tmp/test_bard_lxd.rb", <<~RUBY)
      server :production do
        ssh "deploy@#{@container_ip}"
        path "testproject"
        ssh_key "spec/acceptance/docker/test_key"
        ping false
      end
    RUBY
  end

  after(:all) do
    system("lxc delete --force bard-test-lxd 2>/dev/null")
    FileUtils.rm_f("tmp/test_bard_lxd.rb")
  end

  it "runs ls command on LXD container" do
    # Create test file
    system("lxc exec bard-test-lxd -- su - deploy -c 'touch testproject/lxd-test.txt'")

    Dir.chdir("tmp") do
      File.write("bard.rb", File.read("test_bard_lxd.rb"))
      output, status = Open3.capture2e("bard run ls")
      File.delete("bard.rb")

      expect(status.success?).to be true
      expect(output).to include("lxd-test.txt")
    end
  end

  # Benefits of LXD:
  # - Full systemd init system (can test service management)
  # - More realistic for testing provisioning scripts
  # - Can snapshot and restore states
  # - Very fast startup compared to VMs
  # - Can test apt package installation realistically
end
