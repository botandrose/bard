# Setting Up Podman + TestContainers

This guide shows how to configure TestContainers to use Podman as the backend, giving you the best of both worlds: rootless containers with automatic lifecycle management.

## Prerequisites

```bash
# Install podman (if not already installed)
# Ubuntu/Debian
sudo apt install podman

# Fedora
sudo dnf install podman

# Arch
sudo pacman -S podman
```

## Configure Podman Socket

TestContainers communicates with container runtimes via a Unix socket. Podman provides a Docker-compatible socket:

```bash
# Enable and start the podman socket for your user
systemctl --user enable --now podman.socket

# Verify it's running
systemctl --user status podman.socket

# Check the socket path
ls -la /run/user/$(id -u)/podman/podman.sock
```

## Configure TestContainers to Use Podman

### Option 1: Environment Variable (Recommended for Testing)

```bash
# Add to your shell rc file (~/.bashrc, ~/.zshrc, etc.)
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"

# Or set just for the test run
DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock" rspec spec/acceptance/podman_testcontainers_spec.rb
```

### Option 2: TestContainers Config File

Create `~/.testcontainers.properties`:

```properties
docker.client.strategy=org.testcontainers.dockerclient.UnixSocketClientProviderStrategy
docker.host=unix:///run/user/1000/podman/podman.sock
```

Replace `1000` with your actual UID (`id -u`).

### Option 3: Per-Project Configuration

Create `.testcontainers.properties` in your project root:

```properties
docker.client.strategy=org.testcontainers.dockerclient.UnixSocketClientProviderStrategy
docker.host=unix:///run/user/${USER_ID}/podman/podman.sock
```

## Install TestContainers Gem

```bash
# Add to Gemfile
gem 'testcontainers', group: :test

# Or install directly
gem install testcontainers

bundle install
```

## Build the Test Image

```bash
# Build with podman
podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker
```

## Run the Tests

```bash
# Set the environment variable and run
DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock" rspec spec/acceptance/podman_testcontainers_spec.rb

# Or if you've set it in your shell rc
rspec spec/acceptance/podman_testcontainers_spec.rb
```

## Verify Podman is Being Used

```bash
# In another terminal, watch podman containers while tests run
watch -n 1 'podman ps -a'

# You should see containers being created and destroyed automatically
```

## Troubleshooting

### Socket Permission Denied

```bash
# Make sure the socket is running
systemctl --user status podman.socket

# Restart if needed
systemctl --user restart podman.socket
```

### Container Registry Issues

If you get registry errors, configure podman registries:

```bash
# Edit /etc/containers/registries.conf or ~/.config/containers/registries.conf
[registries.search]
registries = ['docker.io']
```

### Port Already in Use

The POC uses random ports (10000-15000) to avoid conflicts. If you still have issues:

```bash
# Check what's using the ports
ss -tlnp | grep 10000

# Or let the tests use different port ranges by modifying the spec
```

### TestContainers Can't Find Images

```bash
# Pull/build the image first
podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker

# Verify it exists
podman images | grep bard-test-server
```

## Benefits of This Setup

✅ **Rootless** - No sudo required for any operation
✅ **Automatic Lifecycle** - Containers start/stop automatically
✅ **Automatic Cleanup** - Even on test failures
✅ **Parallel Tests** - Each test gets isolated container
✅ **Wait Strategies** - Built-in readiness checks
✅ **No Daemon** - Podman doesn't need a background service
✅ **Better Security** - Rootless containers, no privilege escalation

## Full Integration Example

Once testcontainers gem is installed, you can use:

```ruby
require 'testcontainers'

RSpec.describe "Bard acceptance tests" do
  let(:container) do
    Testcontainers::DockerContainer
      .new("bard-test-server")
      .with_exposed_port(22)
      .with_wait_strategy(
        Testcontainers::WaitStrategies::LogMessageWaitStrategy
          .new("Server listening")
          .with_startup_timeout(30)
      )
  end

  before do
    container.start
  end

  after do
    container.stop  # Automatic cleanup!
  end

  it "runs bard commands" do
    port = container.mapped_port(22)
    # Use the port for SSH commands
    # TestContainers handles everything!
  end
end
```

## Running in CI

TestContainers works great in CI environments:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install Podman
        run: |
          sudo apt-get update
          sudo apt-get install -y podman

      - name: Setup Podman socket
        run: |
          systemctl --user start podman.socket
          echo "DOCKER_HOST=unix:///run/user/$(id -u)/podman/podman.sock" >> $GITHUB_ENV

      - name: Setup Ruby
        uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true

      - name: Run acceptance tests
        run: bundle exec rspec spec/acceptance/podman_testcontainers_spec.rb
```

## Next Steps

1. Install testcontainers gem: `gem install testcontainers`
2. Setup podman socket: `systemctl --user enable --now podman.socket`
3. Set DOCKER_HOST environment variable
4. Run the POC: `rspec spec/acceptance/podman_testcontainers_spec.rb`
5. Uncomment the full testcontainers code in the spec
6. Extend with your own tests!
