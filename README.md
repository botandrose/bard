# Bard

A modular deployment tool for Ruby applications that makes deployment simple and extensible.

## Quick Start

```ruby
# bard.rb
target :production do
  ssh "deploy@example.com:22"
end
```

```bash
bard deploy
```

## Features

- **Modular Capabilities**: Enable only the features you need
- **Pluggable Strategies**: SSH, GitHub Pages, or create your own
- **Default Targets**: Pre-configured for common Bot and Rose workflows
- **Git Integration**: Built-in branch management and safety checks
- **CI Integration**: Auto-detects GitHub Actions or Jenkins
- **Data Syncing**: Copy databases and assets between targets

## Installation

Add to your Gemfile:

```ruby
gem 'bard'
```

Or install globally:

```bash
gem install bard
```

## Core Concepts

### Targets

A **target** is a deployment destination. Targets can be servers, serverless environments, static hosting, or anything else you can deploy to.

```ruby
target :production do
  ssh "deploy@example.com:22", path: "app"
end
```

### Capabilities

Capabilities are features enabled on targets. Common capabilities include:

- **SSH**: Remote command execution and file transfer
- **Ping**: Health check URLs
- **Data**: Database and file syncing
- **Backup**: Automatic backups during deployment

### Deployment Strategies

Strategies determine how code gets deployed. Built-in strategies:

- **SSH**: Deploy via git pull on remote server
- **GitHub Pages**: Deploy static site to gh-pages branch
- **Custom**: Define your own (Jets, Docker, Kubernetes, etc.)

## Configuration

Create a `bard.rb` file in your project root:

```ruby
# Simple SSH deployment
target :production do
  ssh "deploy@example.com:22",
    path: "app",
    gateway: "bastion@example.com:22"
end

# GitHub Pages static site
target :production do
  github_pages "https://example.com"
end

# Custom strategy (Jets serverless)
require_relative 'lib/jets_deploy_strategy'

target :production do
  jets "https://api.example.com", run_tests: true
end
```

## Default Targets

Bard ships with default targets for Bot and Rose workflows. Override any in your `bard.rb`:

- **:local** - Local development (no SSH)
- **:ci** - Jenkins CI at staging.botandrose.com
- **:staging** - Staging server at staging.botandrose.com
- **:gubs** - Bot and Rose cloud server

```ruby
# Override default staging to use Jets
target :staging do
  jets "https://staging-api.example.com"
end

# Keep :ci, :gubs, :local as defaults
```

## Commands

### Deployment

```bash
# Deploy current branch to production (default)
bard deploy

# Deploy a specific branch to production
bard deploy feature-branch

# Deploy to a different target
bard deploy --target=staging
bard deploy feature-branch --target=staging

# Deploy feature branch to staging (no merge)
bard stage feature-branch

# Skip CI checks
bard deploy --skip-ci
```

### Data Management

```bash
# Copy database and assets from production to local
bard data --from=production --to=local

# Copy staging data to local
bard data --from=staging --to=local

# Configure additional paths to sync
# bard.rb:
data "public/uploads", "public/system"
```

### SSH Commands

```bash
# SSH into a target
bard ssh production

# Run a command on a target
bard run production "bundle exec rails console"
```

### CI

```bash
# Run CI for current branch
bard ci

# Run tests locally
bard ci --local-ci

# Check CI status
bard ci --status
```

### Utilities

```bash
# Open target URL in browser
bard open production

# Ping target to check health
bard ping production

# Show uncommitted changes
bard hurt

# Open changed files in vim
bard vim
```

### Provisioning

```bash
# Full server provisioning
bard provision deploy@new-server.com:22

# Configure nginx for current app
bard setup
```

## SSH Capability

Enable SSH to run commands and transfer files:

```ruby
target :production do
  ssh "user@host:port",
    path: "deploy/path",
    gateway: "bastion@host:port",
    ssh_key: "/path/to/key",
    env: "RAILS_ENV=production"
end
```

This provides:
- `target.run!(command)` - Execute remote command (raises on error)
- `target.run(command)` - Execute remote command (silent on error)
- `target.exec!(command)` - Replace process with remote command
- `target.copy_file(path, to: target)` - Copy file to another target
- `target.copy_dir(path, to: target)` - Rsync directory to another target

## Deployment Strategies

### SSH Strategy

Deploy by running git pull on remote server:

```ruby
target :production do
  ssh "deploy@example.com:22"
end
```

Deployment runs: `git pull origin master && bin/setup`

### GitHub Pages Strategy

Deploy static site to GitHub Pages:

```ruby
target :production do
  github_pages "https://example.com"
end
```

Deployment:
1. Starts Rails server locally
2. Mirrors site with wget
3. Creates orphan commit with static assets
4. Force-pushes to `gh-pages` branch

### Custom Strategies

Create your own deployment strategy:

```ruby
# lib/jets_deploy_strategy.rb
module Bard
  class DeployStrategy
    class Jets < DeployStrategy
      def deploy
        target_name = target.key.to_s
        options = target.strategy_options(:jets)

        run! "rake vips:build:#{target_name}" unless options[:skip_build]
        run! "bundle exec rspec" if should_run_tests?(target_name, options)
        run! "jets deploy #{options[:env] || target_name}"
      end

      private

      def should_run_tests?(target_name, options)
        return options[:run_tests] if options.key?(:run_tests)
        target_name == "production"
      end
    end
  end
end
```

Use it in your `bard.rb`:

```ruby
require_relative 'lib/jets_deploy_strategy'

target :production do
  jets "https://api.example.com", run_tests: true
end

target :staging do
  jets "https://staging-api.example.com", skip_build: true
end
```

Strategies auto-register via Ruby's `inherited` hook - no manual registration needed!

## CI Configuration

Bard auto-detects your CI system:
- Finds `.github/workflows/ci.yml` → GitHub Actions
- Otherwise → Jenkins (legacy)

Override via DSL:

```ruby
# Force specific CI system
ci :github_actions
ci :jenkins
ci :local

# Disable CI
ci false
```

## Ping Configuration

Configure health check URLs:

```ruby
target :production do
  ssh "deploy@example.com:22"
  ping "https://example.com", "/health", "/status"
end
```

Auto-configured by deployment strategies:

```ruby
# Ping URL automatically set from Jets URL
target :production do
  jets "https://api.example.com"
end
```

## Data Syncing

Database syncing is enabled by default when SSH is configured. Add file paths to sync:

```ruby
# Global configuration
data "public/uploads", "public/system"

target :production do
  ssh "deploy@example.com:22"
end
```

Then sync:

```bash
bard data --from=production --to=local
```

This:
1. Runs `bin/rake db:dump` on source
2. Copies `db/data.sql.gz` via SCP
3. Runs `bin/rake db:load` on destination
4. Rsyncs configured data paths

## Backup Configuration

Control whether backups are created during deployment:

```ruby
# Enable backups (default for SSH deployments)
backup true

# Disable backups (typical for serverless/static)
backup false
```

## Example Configurations

### Traditional Rails App

```ruby
target :staging do
  ssh "deploy@staging.example.com:22"
end

target :production do
  ssh "deploy@production.example.com:22"
end

data "public/uploads"
backup true
```

### Serverless API (Jets)

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

### Hybrid (Jets + SSH for debugging)

```ruby
require_relative 'lib/jets_deploy_strategy'

target :staging do
  jets "https://staging-api.example.com"
  ssh "deploy@bastion.example.com:22"  # Enables SSH commands
end

target :production do
  jets "https://api.example.com"
  # No SSH in production
end

backup false
```

### Static Site

```ruby
target :production do
  github_pages "https://example.com"
end

backup false
```

### Override Default Targets

```ruby
# Override default staging to use Jets
target :staging do
  jets "https://staging-api.example.com"
end

# Keep :ci, :gubs, :local targets as defaults
```

## Migration from v1.x

See [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed migration instructions.

Key changes in v2.0:
- `server` renamed to `target`
- SSH configuration uses hash options
- Strategy-first configuration
- Capability-based commands

## Architecture

Bard follows a modular, capability-based architecture:

- **Core**: Minimal git workflow and configuration
- **Capabilities**: Features enabled via DSL methods
- **Strategies**: Pluggable deployment strategies with auto-registration
- **Subsystems**: Independent and composable

See [ARCHITECTURE.md](ARCHITECTURE.md) for detailed architecture documentation.

## Custom Strategy Guide

See [CUSTOM_STRATEGIES.md](CUSTOM_STRATEGIES.md) for a step-by-step guide to creating custom deployment strategies.

## Plugin Development

See [PLUGINS.md](PLUGINS.md) for a guide to creating plugins.

## Development

```bash
# Clone repository
git clone https://github.com/botandrose/bard.git
cd bard

# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run bard from source
bundle exec bin/bard
```

## License

MIT License. Copyright (c) 2018 Micah Geisel. See LICENSE for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
