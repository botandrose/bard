# Running Acceptance Tests

The acceptance tests in this directory require podman (or docker) to be able to pull container images from the network.

## Quick Start

If you're in an environment with network access to container registries:

```bash
# Generate SSH keys (already done if they exist)
ssh-keygen -t rsa -b 2048 -f spec/acceptance/docker/test_key -N '' -C 'bard-test-key'

# Run the podman acceptance tests
rspec spec/acceptance/podman_ssh_spec.rb
rspec spec/acceptance/podman_testcontainers_spec.rb

# Or run all acceptance tests
rspec spec/acceptance/
```

## Why Tests Are Skipped

The tests will skip (show as "pending") if:
- Network access to container registries is blocked
- Unable to pull base images (ubuntu:22.04)
- Podman is not installed

This is by design - the tests gracefully skip in restricted environments.

## Running Tests Successfully

### Prerequisites

1. **Install Podman**:
   ```bash
   # Ubuntu/Debian
   sudo apt install podman

   # Fedora
   sudo dnf install podman

   # Arch
   sudo pacman -S podman
   ```

2. **Network Access**: Ensure your environment can access `docker.io` registry

3. **SSH Keys**: Generate test SSH keys (already created in this repo)

### Run Podman SSH Tests

```bash
# This test validates basic podman container SSH connectivity
rspec spec/acceptance/podman_ssh_spec.rb --format documentation
```

### Run Podman + TestContainers Tests

```bash
# Set up podman socket for testcontainers
systemctl --user enable --now podman.socket
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"

# Install testcontainers gem
gem install testcontainers

# Run the test
rspec spec/acceptance/podman_testcontainers_spec.rb --format documentation
```

## Expected Output (When Passing)

```
Bard run command with Podman SSH server
  runs ls command on remote server

Finished in X.XX seconds
1 example, 0 failures
```

## Expected Output (When Skipped)

```
Bard run command with Podman SSH server
  runs ls command on remote server (PENDING: Cannot pull images in this environment)

Finished in X.XX seconds
1 example, 0 failures, 1 pending
```

## Troubleshooting

### "Cannot pull images" Error

This means the test environment cannot access container registries. Solutions:

1. **Check network**: `podman pull ubuntu:22.04`
2. **Configure proxy** (if behind corporate firewall):
   ```bash
   export HTTP_PROXY=http://proxy:port
   export HTTPS_PROXY=http://proxy:port
   ```
3. **Use cached image**: If you have the image locally, it will be used

### "Port already in use" Error

The tests use specific ports (2223, etc.). If they're in use:

```bash
# Stop any existing test containers
podman rm -f bard-test-podman bard-test-tc

# Or change the ports in the spec files
```

### Permission Errors with SSH Keys

```bash
chmod 600 spec/acceptance/docker/test_key
chmod 644 spec/acceptance/docker/test_key.pub
```

## Running in CI

For GitHub Actions or other CI:

```yaml
- name: Run acceptance tests
  run: |
    # Install podman
    sudo apt-get update
    sudo apt-get install -y podman

    # Run tests
    rspec spec/acceptance/podman_ssh_spec.rb
```

## Development Workflow

When developing acceptance tests:

1. **Unit tests first**: Write unit tests (fast, no containers needed)
2. **Acceptance tests locally**: Test with podman on your machine
3. **CI validation**: Let CI run acceptance tests automatically
4. **Tag appropriately**: Use `:acceptance` tag for easier filtering

```ruby
RSpec.describe "Feature", type: :acceptance, acceptance: true do
  # ...
end
```

Then run only acceptance tests with:
```bash
rspec --tag acceptance
```

Or exclude them for faster local runs:
```bash
rspec --tag ~acceptance
```
