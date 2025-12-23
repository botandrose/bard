# Migration Guide: Bard v1.x → v2.0

This guide will help you migrate your Bard configuration from v1.x to v2.0.

> **Note:** Bard v1.8.0 is a transitional release that supports both v1.x and v2.0 APIs. When using deprecated v1.x patterns, you'll see deprecation warnings indicating what to change. This gives you time to migrate at your own pace while keeping your deployments working.

## Overview of Changes

Bard v2.0 introduces a cleaner, more modular architecture:

1. **`server` renamed to `target`** - More accurate for serverless deployments
2. **SSH configuration simplified** - Uses hash options instead of separate method calls
3. **Strategy-first configuration** - Deployment strategies provide their own configuration
4. **Capability-based architecture** - Features are explicitly enabled and checked
5. **Default targets** - Pre-configured targets for Bot and Rose workflows

## Breaking Changes

### 1. `server` → `target`

**v1.x:**
```ruby
server :production do
  ssh "deploy@example.com:22"
end
```

**v2.0:**
```ruby
target :production do
  ssh "deploy@example.com:22"
end
```

**Migration:** Simply replace `server` with `target` throughout your `bard.rb`.

### 2. SSH Configuration

SSH configuration now uses hash options instead of separate method calls.

**v1.x:**
```ruby
server :production do
  ssh "user@host:port"
  path "deploy/path"
  gateway "bastion@host:port"
  key "/path/to/key"
  env "RAILS_ENV=production"
end
```

**v2.0:**
```ruby
target :production do
  ssh "user@host:port",
    path: "deploy/path",
    gateway: "bastion@host:port",
    ssh_key: "/path/to/key",
    env: "RAILS_ENV=production"
end
```

**Migration:**
- Combine all SSH-related options into the `ssh` method call
- `key` → `ssh_key`
- Use Ruby hash syntax for options

### 3. GitHub Pages Configuration

**v1.x:**
```ruby
server :production do
  github_pages true
  ping "https://example.com"
end
```

**v2.0:**
```ruby
target :production do
  github_pages "https://example.com"  # Sets both strategy and ping URL
end
```

**Migration:**
- Pass the ping URL directly to `github_pages`
- Remove separate `ping` call (auto-configured by strategy)

### 4. Strategy-First Configuration

In v2.0, deployment strategies configure themselves.

**v1.x:**
```ruby
server :production do
  strategy :jets
  ping "https://api.example.com"
  option :run_tests, true
end
```

**v2.0:**
```ruby
target :production do
  jets "https://api.example.com", run_tests: true
end
```

**Migration:**
- Use strategy name as DSL method
- Pass ping URL and options directly
- Remove separate `strategy`, `ping`, and `option` calls

## Migration Examples

### Example 1: Simple SSH Deployment

**v1.x:**
```ruby
server :staging do
  ssh "deploy@staging.example.com:22"
  path "app"
end

server :production do
  ssh "deploy@production.example.com:22"
  path "app"
  gateway "bastion.example.com:22"
end

data "public/uploads"
```

**v2.0:**
```ruby
target :staging do
  ssh "deploy@staging.example.com:22", path: "app"
end

target :production do
  ssh "deploy@production.example.com:22",
    path: "app",
    gateway: "bastion.example.com:22"
end

data "public/uploads"
```

### Example 2: GitHub Pages

**v1.x:**
```ruby
server :production do
  github_pages true
  ping "https://example.com"
  backup false
end
```

**v2.0:**
```ruby
target :production do
  github_pages "https://example.com"
end

backup false
```

### Example 3: Jets Serverless

**v1.x:**
```ruby
require_relative 'lib/jets_deploy_strategy'

server :staging do
  strategy :jets
  ping "https://staging-api.example.com"
end

server :production do
  strategy :jets
  ping "https://api.example.com"
  option :run_tests, true
end

backup false
```

**v2.0:**
```ruby
require_relative 'lib/jets_deploy_strategy'

target :staging do
  jets "https://staging-api.example.com"
end

target :production do
  jets "https://api.example.com", run_tests: true
end

backup false
```

### Example 4: Multiple Ping URLs

**v1.x:**
```ruby
server :production do
  ssh "deploy@example.com:22"
  ping "https://example.com"
  ping "/health"
  ping "/status"
end
```

**v2.0:**
```ruby
target :production do
  ssh "deploy@example.com:22"
  ping "https://example.com", "/health", "/status"
end
```

### Example 5: CI Configuration

**v1.x:**
```ruby
# CI auto-detected, no explicit configuration
```

**v2.0:**
```ruby
# CI auto-detected by default

# Override if needed:
ci :github_actions  # Force GitHub Actions
ci :jenkins         # Force Jenkins
ci :local           # Run locally
ci false            # Disable CI
```

## Step-by-Step Migration Process

### Step 1: Update Bard gem

```bash
# Gemfile
gem 'bard', '~> 2.0'
```

```bash
bundle update bard
```

### Step 2: Update bard.rb configuration

1. Replace `server` with `target`
2. Combine SSH options into hash
3. Update strategy configuration to use DSL methods
4. Simplify ping configuration

### Step 3: Test locally

```bash
# Verify configuration loads
bard config

# Test SSH connection (if applicable)
bard ssh staging

# Test ping (if applicable)
bard ping staging
```

### Step 4: Deploy to staging

```bash
bard deploy staging
```

### Step 5: Deploy to production

```bash
bard deploy production
```

## Automated Migration Script

You can use this Ruby script to automatically migrate simple configurations:

```ruby
#!/usr/bin/env ruby
# migrate_bard_config.rb

config = File.read('bard.rb')

# Replace server with target
config.gsub!(/^(\s*)server\s+/, '\1target ')

# Combine SSH options (simple cases)
config.gsub!(
  /ssh\s+"([^"]+)"\s+path\s+"([^"]+)"/m,
  'ssh "\1", path: "\2"'
)

# GitHub Pages
config.gsub!(
  /github_pages\s+true\s+ping\s+"([^"]+)"/m,
  'github_pages "\1"'
)

puts config
```

Run with:
```bash
ruby migrate_bard_config.rb > bard.rb.new
mv bard.rb bard.rb.backup
mv bard.rb.new bard.rb
```

**Note:** This script handles simple cases. Review the output and manually update complex configurations.

## Common Pitfalls

### Pitfall 1: Forgetting to combine SSH options

**Wrong:**
```ruby
target :production do
  ssh "deploy@example.com:22"
  path "app"  # This won't work in v2!
end
```

**Right:**
```ruby
target :production do
  ssh "deploy@example.com:22", path: "app"
end
```

### Pitfall 2: Using old strategy configuration

**Wrong:**
```ruby
target :production do
  strategy :jets
  ping "https://api.example.com"
end
```

**Right:**
```ruby
target :production do
  jets "https://api.example.com"
end
```

### Pitfall 3: Separate ping calls

**Wrong:**
```ruby
target :production do
  github_pages true
  ping "https://example.com"
end
```

**Right:**
```ruby
target :production do
  github_pages "https://example.com"
end
```

## Capability Dependencies

v2.0 makes capability dependencies explicit. If you try to use a command that requires a capability you haven't enabled, you'll get a clear error message.

### SSH-dependent commands

These commands require SSH capability:
- `bard ssh [target]`
- `bard run [target] "command"`
- `bard data --from=X --to=Y` (both targets need SSH)
- `bard master_key --from=X --to=Y` (both targets need SSH)

**Enable SSH:**
```ruby
target :production do
  ssh "deploy@example.com:22"
end
```

### Ping-dependent commands

These commands require ping URLs:
- `bard ping [target]`
- `bard open [target]`

**Enable ping:**
```ruby
target :production do
  ssh "deploy@example.com:22"
  ping "https://example.com"
end

# Or let strategy auto-configure:
target :production do
  jets "https://api.example.com"  # Ping auto-configured
end
```

## Default Targets

v2.0 ships with default targets for Bot and Rose workflows. You only need to define targets you want to customize.

**Default targets:**
- `:local` - Local development (no SSH, path `./`, ping `#{project_name}.local`)
- `:ci` - Jenkins at `staging.botandrose.com`
- `:staging` - SSH to `staging.botandrose.com`
- `:gubs` - Bot and Rose cloud server

**Override any default:**
```ruby
# Override staging to use Jets instead of SSH
target :staging do
  jets "https://staging-api.example.com"
end

# Keep :ci, :gubs, :local as defaults (no config needed)
```

## Custom Strategies

If you created custom deployment strategies in v1.x, you'll need to update them for v2.0's auto-registration system.

**v1.x:**
```ruby
# Manual registration required
Bard::DeployStrategy.register(:jets, JetsDeployStrategy)
```

**v2.0:**
```ruby
# Auto-registers via inherited hook
module Bard
  class DeployStrategy
    class Jets < DeployStrategy
      def deploy
        # implementation
      end
    end
  end
end
```

See [CUSTOM_STRATEGIES.md](CUSTOM_STRATEGIES.md) for detailed guide.

## Rollback Plan

If you encounter issues, you can rollback to v1.x:

```bash
# Gemfile
gem 'bard', '~> 1.5'

bundle update bard

# Restore backup
mv bard.rb.backup bard.rb
```

## Getting Help

- Review [README.md](README.md) for v2 API documentation
- Review [ARCHITECTURE.md](ARCHITECTURE.md) for architecture details
- Check [CUSTOM_STRATEGIES.md](CUSTOM_STRATEGIES.md) for strategy creation
- Open an issue at https://github.com/botandrose/bard/issues

## Transitional Release (v1.8.0)

Bard v1.8.0 is a transitional release that supports both v1.x and v2.0 APIs simultaneously with deprecation warnings. This allows gradual migration.

**Using v1.8.0:**
```bash
# Gemfile
gem 'bard', '~> 1.8'

bundle update bard
```

v1.8.0 will:
- Accept both `server` and `target` (with deprecation warning for `server`)
- Accept both old and new SSH configuration styles (with deprecation warnings for separate options)
- Accept both old `strategy`/`option` calls and new direct strategy methods (with deprecation warnings)
- Show deprecation warnings for all deprecated v1.x API usage
- Support full v2.0 API

This gives you time to migrate at your own pace while keeping your deployments working.

### Deprecation Warnings

When using deprecated patterns, you'll see warnings like:

```
[DEPRECATION] `server` is deprecated; use `target` instead (will be removed in v2.0) (called from bard.rb:3)
[DEPRECATION] Separate SSH options are deprecated; pass as keyword arguments to `ssh` instead (will be removed in v2.0) (called from bard.rb:5)
[DEPRECATION] `strategy` is deprecated; use the strategy method directly (will be removed in v2.0) (called from bard.rb:10)
```

These warnings help you identify what needs to change before upgrading to v2.0.
