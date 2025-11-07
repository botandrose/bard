# Acceptance Testing Options - Summary

## What I Created

I've built proof-of-concept acceptance tests for 5 different approaches to test Bard end-to-end:

### Files Created

```
spec/acceptance/
├── README.md                    # Comprehensive guide
├── SUMMARY.md                   # This file
├── docker/
│   ├── Dockerfile              # Base SSH server image
│   ├── docker-compose.yml      # Multi-server setup
│   ├── test_key                # SSH private key (placeholder)
│   └── test_key.pub            # SSH public key (placeholder)
├── docker_ssh_spec.rb          # Option 1: Docker
├── podman_ssh_spec.rb          # Option 2: Podman (rootless!)
├── testcontainers_spec.rb      # Option 3: TestContainers
├── lxd_spec.rb                 # Option 4: LXD/LXC
├── systemd_nspawn_spec.rb      # Option 5: systemd-nspawn
└── multi_server_spec.rb        # Bonus: Multi-server testing
```

## Quick Decision Guide

### "I want the simplest, no-sudo solution"
→ **Use Podman** (`podman_ssh_spec.rb`)
- Rootless (no sudo needed!)
- Docker-compatible
- Just works

### "I want the most portable solution"
→ **Use Docker** (`docker_ssh_spec.rb`)
- Works everywhere
- Huge ecosystem
- Well documented

### "I want automatic cleanup and CI/CD integration"
→ **Use TestContainers** (`testcontainers_spec.rb`)
- Programmatic lifecycle
- Auto-cleanup on failure
- Perfect for CI

### "I need to test provisioning scripts with systemd"
→ **Use LXD** (`lxd_spec.rb`)
- Full init system
- Real systemd services
- Can test apt packages

### "I need maximum performance"
→ **Use systemd-nspawn** (`systemd_nspawn_spec.rb`)
- Minimal overhead
- Built into systemd
- (But requires root)

## My Recommendation

**Start with Podman:**

```bash
# Install podman (if not already installed)
# Ubuntu: sudo apt install podman
# Fedora: sudo dnf install podman
# macOS: brew install podman

# Build test image
podman build -t bard-test-server -f spec/acceptance/docker/Dockerfile spec/acceptance/docker

# Run the test
rspec spec/acceptance/podman_ssh_spec.rb
```

**Why Podman?**
1. ✅ Rootless - no sudo required
2. ✅ Docker-compatible (same Dockerfiles)
3. ✅ No daemon needed
4. ✅ Works great on Linux (which Bard requires anyway)
5. ✅ Better security model

## Testing Multi-Server Workflows

For testing `bard stage` → `bard deploy` type workflows:

```bash
# Start both staging and production
cd spec/acceptance/docker
podman-compose up -d  # or docker-compose

# Run multi-server tests
rspec spec/acceptance/multi_server_spec.rb

# Cleanup
podman-compose down  # or docker-compose
```

## Next Steps

1. **Generate real SSH keys** (the current ones are placeholders):
   ```bash
   ssh-keygen -t rsa -b 2048 -f spec/acceptance/docker/test_key -N ''
   ```

2. **Choose your approach** and try the POC test

3. **Extend the tests** to cover your specific workflows:
   - Database syncing (`bard data`)
   - Deployments (`bard deploy`)
   - Provisioning (`bard provision`)
   - CI integration (`bard ci`)

4. **Add to your test suite**:
   ```ruby
   # spec/spec_helper.rb
   RSpec.configure do |config|
     # Only run acceptance tests when explicitly requested
     config.filter_run_excluding acceptance: true unless ENV['ACCEPTANCE']
   end
   ```

   Then tag your acceptance specs:
   ```ruby
   RSpec.describe "Bard run", type: :acceptance, acceptance: true do
   ```

   Run with:
   ```bash
   ACCEPTANCE=1 rspec spec/acceptance/
   ```

## Performance Comparison

Based on typical startup times:

| Approach | Startup | Setup Complexity | Isolation | systemd |
|----------|---------|------------------|-----------|---------|
| Podman | 2-5s | Low | Good | No |
| Docker | 2-5s | Low | Good | No |
| TestContainers | 2-5s | Low | Good | No |
| LXD | 5-10s | Medium | Excellent | Yes |
| systemd-nspawn | 1-2s | High | Medium | Yes |

## Questions?

See `spec/acceptance/README.md` for detailed documentation on each approach.
