# Acceptance Tests for Bard

This directory contains end-to-end acceptance tests for Bard using Podman and TestContainers.

## Overview

The acceptance tests validate Bard's functionality by:
- Starting real SSH server containers
- Running `bard` commands against them
- Verifying the output
- Automatically cleaning up containers

## Prerequisites

### 1. Install Podman

```bash
# Ubuntu/Debian
sudo apt install podman

# Fedora
sudo dnf install podman

# macOS (requires podman machine)
brew install podman
```

### 2. Install TestContainers Gem

```bash
gem install testcontainers
```

### 3. Start Podman Socket

TestContainers communicates with Podman via a Unix socket:

```bash
# Create the socket directory if it doesn't exist
mkdir -p /run/user/$(id -u)/podman

# Start the podman socket
systemctl --user start podman.socket

# Or manually:
podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &
```

### 4. Configure Environment

```bash
# Set DOCKER_HOST to point to podman socket
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"

# Add to ~/.bashrc or ~/.zshrc to persist
echo 'export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"' >> ~/.bashrc
```

## Running the Tests

```bash
# Run all acceptance tests
rspec spec/acceptance/

# Run specific test
rspec spec/acceptance/podman_testcontainers_spec.rb

# With detailed output
rspec spec/acceptance/podman_testcontainers_spec.rb --format documentation
```

## How It Works

1. **Test Setup**: TestContainers pulls the `ubuntu:22.04` image and builds the `bard-test-server` container
2. **Container Start**: Each test gets its own isolated SSH server container
3. **SSH Setup**: Test creates a user, sets up SSH keys, and waits for SSH to be ready
4. **Bard Execution**: Test runs `bard run ls` (or other commands) against the container
5. **Verification**: Test checks that the output is correct
6. **Cleanup**: TestContainers automatically stops and removes the container

## Benefits

- **Rootless**: No sudo required (Podman runs rootless)
- **Automatic Lifecycle**: Containers start/stop automatically
- **Automatic Cleanup**: Even on test failures
- **Isolated**: Each test gets its own container
- **Parallel-safe**: Random ports prevent conflicts

## Troubleshooting

### "Cannot pull images"

This is expected in restricted network environments. The test will skip gracefully.

To run successfully, ensure:
- Network access to docker.io registry
- Podman can pull images: `podman pull ubuntu:22.04`

### "Connection refused" on SSH

The test waits up to 15 seconds for SSH to be ready. If it still fails:
- Check container logs: `podman logs <container-name>`
- Verify SSH is running: `podman exec <container-name> systemctl status ssh`

### "Command not found: bard"

Ensure the `bard` gem is installed and in your PATH:
```bash
gem install bard
# Or use bundle
bundle exec rspec spec/acceptance/
```

## File Structure

```
spec/acceptance/
├── README.md                       # This file
├── podman_testcontainers_spec.rb   # Main acceptance test
└── docker/
    ├── Dockerfile                  # SSH server container image
    ├── test_key                    # SSH private key for tests
    └── test_key.pub                # SSH public key
```

## CI/CD Integration

For GitHub Actions:

```yaml
name: Acceptance Tests
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Podman
        run: sudo apt-get install -y podman

      - name: Setup Podman Socket
        run: |
          mkdir -p /run/user/$(id -u)/podman
          podman system service --time=0 unix:///run/user/$(id -u)/podman/podman.sock &
          sleep 2

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Install TestContainers
        run: gem install testcontainers

      - name: Run Acceptance Tests
        env:
          DOCKER_HOST: unix:///run/user/${{ github.event.sender.id }}/podman/podman.sock
        run: rspec spec/acceptance/
```

## Writing New Tests

Add new test cases to `podman_testcontainers_spec.rb`:

```ruby
it "does something new" do
  # Create test data in container
  system("ssh -o StrictHostKeyChecking=no -p #{ssh_port} deploy@localhost -i spec/acceptance/docker/test_key 'touch testproject/newfile.txt'")

  # Run bard command
  Dir.chdir("tmp") do
    FileUtils.cp("../#{@bard_config_path}", "bard.rb")
    output, status = Open3.capture2e("bard run 'your-command-here'")
    FileUtils.rm_f("bard.rb")

    # Verify results
    expect(status.success?).to be true
    expect(output).to include("expected content")
  end
end
```

## Security Note

The SSH keys in `docker/` directory are for **testing purposes only**. They are committed to the repository and should never be used in production.
