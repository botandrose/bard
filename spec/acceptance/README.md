# Bard Acceptance Testing - Proof of Concepts

This directory contains proof-of-concept acceptance tests for Bard using different containerization/virtualization approaches.

## Overview

Bard orchestrates SSH connections, file transfers, database operations, and server provisioning. Traditional unit tests mock these interactions, but acceptance tests run against real SSH servers to catch integration issues.

## Test Approaches

### 1. Docker with SSH (`docker_ssh_spec.rb`)
**Recommended for most users**

```bash
# Setup
docker build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker

# Run tests
rspec spec/acceptance/docker_ssh_spec.rb

# Cleanup
docker rm -f bard-test-ssh
```

**Pros:**
- Most portable (works everywhere Docker runs)
- Fast container startup (~2-5 seconds)
- Easy to version control infrastructure
- Large ecosystem and documentation
- Can use docker-compose for multi-server tests

**Cons:**
- Requires Docker daemon (with root/sudo)
- Slight overhead compared to native containers

### 2. Podman with SSH (`podman_ssh_spec.rb`)
**Recommended if you want rootless containers**

```bash
# Setup
podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker

# Run tests
rspec spec/acceptance/podman_ssh_spec.rb

# Cleanup
podman rm -f bard-test-podman
```

**Pros:**
- **Rootless - no sudo required!**
- Daemonless architecture
- Docker-compatible (same Dockerfiles/commands)
- Better security model
- Native systemd integration

**Cons:**
- Less common than Docker (may need installation)
- Some minor behavioral differences from Docker

### 2.5. Podman + TestContainers (`podman_testcontainers_spec.rb`)
**BEST OF BOTH WORLDS - Recommended!**

```bash
# One-time setup
systemctl --user enable --now podman.socket
export DOCKER_HOST="unix:///run/user/$(id -u)/podman/podman.sock"
gem install testcontainers

# Build image
podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker

# Run tests (automatic lifecycle!)
rspec spec/acceptance/podman_testcontainers_spec.rb
```

**Pros:**
- **Rootless - no sudo required!**
- **Automatic lifecycle management** (start/stop/cleanup)
- **Automatic cleanup on test failures**
- Isolated containers per test
- Random ports avoid conflicts
- Can run tests in parallel
- Daemonless (podman)

**Cons:**
- Requires testcontainers gem
- Requires podman socket setup (one-time)

See `SETUP_PODMAN_TESTCONTAINERS.md` for detailed setup instructions.

### 3. TestContainers (`testcontainers_spec.rb`)
**Recommended for programmatic container management**

```bash
# Install gem
gem install testcontainers

# Run tests (containers managed automatically)
rspec spec/acceptance/testcontainers_spec.rb
```

**Pros:**
- Automatic container lifecycle management
- Built-in wait strategies for readiness
- Automatic cleanup even on failures
- Great for CI/CD pipelines
- Supports docker-compose

**Cons:**
- Requires Docker daemon
- Additional dependency (testcontainers gem)

### 4. LXD/LXC (`lxd_spec.rb`)
**Recommended for testing provisioning scripts**

```bash
# One-time LXD setup
sudo snap install lxd
sudo lxd init --auto

# Run tests
rspec spec/acceptance/lxd_spec.rb

# Cleanup
lxc delete --force bard-test-lxd
```

**Pros:**
- Full systemd init system (real services)
- Very fast startup (~5-10 seconds for full OS)
- More realistic for testing apt/systemd provisioning
- Can snapshot/restore states
- Linux-native, extremely efficient

**Cons:**
- Linux-only
- Requires LXD setup
- Different paradigm from Docker

### 5. systemd-nspawn (`systemd_nspawn_spec.rb`)
**Only for advanced use cases**

```bash
# One-time setup (requires root)
sudo debootstrap --variant=minbase jammy /var/lib/machines/bard-test

# Run tests
rspec spec/acceptance/systemd_nspawn_spec.rb
```

**Pros:**
- Minimal overhead
- Built into systemd (no extra software)
- Very fast

**Cons:**
- Requires root for most operations
- Manual setup required
- Less isolation
- Not portable

## Generating Real SSH Keys

The included test keys are placeholders. Generate real keys:

```bash
ssh-keygen -t rsa -b 2048 -f spec/acceptance/docker/test_key -N '' -C 'bard-test-key'
chmod 600 spec/acceptance/docker/test_key
chmod 644 spec/acceptance/docker/test_key.pub
```

## Comparison Matrix

| Feature | Docker | Podman | Podman+TC | TestContainers | LXD | systemd-nspawn |
|---------|--------|--------|-----------|----------------|-----|----------------|
| Rootless | ❌ | ✅ | ✅ | ❌ | ❌ | ❌ |
| Auto Lifecycle | ❌ | ❌ | ✅✅ | ✅✅ | ❌ | ❌ |
| Auto Cleanup | ❌ | ❌ | ✅✅ | ✅✅ | ❌ | ❌ |
| Startup Speed | Fast (2-5s) | Fast (2-5s) | Fast (2-5s) | Fast (2-5s) | Very Fast (5-10s) | Very Fast (1-2s) |
| Full systemd | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Portable | ✅ | ✅ | ✅ | ✅ | ❌ (Linux) | ❌ (Linux) |
| Easy Setup | ✅ | ✅ | ⚠️ Medium | ✅ | ⚠️ Medium | ❌ Hard |
| CI Friendly | ✅ | ✅ | ✅✅✅ | ✅✅ | ⚠️ | ❌ |
| Ecosystem | ✅✅✅ | ✅✅ | ✅✅ | ✅✅ | ✅ | ⚠️ |

## Recommendations

**🏆 BEST OVERALL:** **Podman + TestContainers** (rootless + automatic lifecycle)
- See `SETUP_PODMAN_TESTCONTAINERS.md` for setup guide
- One-time setup, then it just works!

**For simplicity:** Start with **Podman** alone (rootless, no daemon)
- Fallback to Docker if Podman unavailable
- Manual lifecycle but very simple

**For CI/CD:** Use **TestContainers** (with Docker or Podman)
- Automatic lifecycle management
- Perfect for GitHub Actions/Jenkins

**For testing provisioning/systemd:** Use **LXD** (full init system)
- Can test real apt packages, systemd services, etc.

**Multi-server testing:** Use **docker-compose** or **podman-compose**

## Multi-Server Example

For testing `bard stage` → `bard deploy` workflows:

```yaml
# spec/acceptance/docker-compose.yml
services:
  staging:
    build: ./docker
    ports: ["2222:22"]
    hostname: staging
  production:
    build: ./docker
    ports: ["2223:22"]
    hostname: production
```

Then test data sync:
```ruby
it "syncs data from staging to local" do
  # Setup staging with test data
  ssh("staging", "psql -c 'CREATE TABLE test...'")

  # Run bard data staging
  system("bard data staging")

  # Verify local has the data
  expect(ActiveRecord::Base.connection.tables).to include('test')
end
```

## Running All Acceptance Tests

```bash
# Tag specs
# spec/spec_helper.rb:
RSpec.configure do |config|
  config.filter_run_excluding acceptance: true unless ENV['ACCEPTANCE']
end

# Run only acceptance tests
ACCEPTANCE=1 rspec spec/acceptance/

# Or run specific approach
rspec spec/acceptance/podman_ssh_spec.rb
```
