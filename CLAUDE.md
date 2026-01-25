# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is Bard?

Bard is a modular deployment CLI tool for Ruby applications. It provides:
- SSH-based deployment via git pull
- GitHub Pages static site deployment
- Custom pluggable deployment strategies
- Data syncing (database dumps and file rsync)
- CI integration (GitHub Actions/Jenkins)
- Server provisioning

## Development Commands

```bash
# Install dependencies
bundle install

# Run all tests (RSpec + Cucumber)
bundle exec rake

# Run only RSpec tests
bundle exec rspec

# Run a single spec file
bundle exec rspec spec/bard/target_spec.rb

# Run a specific test by line number
bundle exec rspec spec/bard/target_spec.rb:42

# Run Cucumber features (slow - avoid full suite)
bundle exec cucumber features/deploy.feature

# Run bard from source
bundle exec bin/bard
```

## Architecture

### Core Classes

- **`Bard::CLI`** (`lib/bard/cli.rb`) - Thor-based command dispatcher. Commands are modules in `lib/bard/cli/` included into CLI.
- **`Bard::Config`** (`lib/bard/config.rb`) - DSL parser for `bard.rb` files. Manages targets and settings.
- **`Bard::Target`** (`lib/bard/target.rb`) - Deployment destination with capabilities (ssh, ping, data). Supports dynamic strategy DSL via `method_missing`.
- **`Bard::Server`** (`lib/bard/server.rb`) - Legacy v1.x server representation (deprecated, use Target).
- **`Bard::DeployStrategy`** (`lib/bard/deploy_strategy.rb`) - Base class for deployment strategies. Subclasses auto-register via Ruby's `inherited` hook.

### Capability System

Targets track enabled capabilities (`:ssh`, `:ping`, `:github_pages`, etc.). Commands call `require_capability!` to ensure the target supports the operation.

### Strategy Auto-Registration

Custom strategies subclass `DeployStrategy` and are automatically registered by class name:
```ruby
class Bard::DeployStrategy::Jets < DeployStrategy  # registers as :jets
  def deploy; ...; end
end
```

### File Organization

- `lib/bard/cli/*.rb` - CLI command modules (deploy, data, ssh, etc.)
- `lib/bard/ci/*.rb` - CI system integrations (github_actions, jenkins, local)
- `lib/bard/deploy_strategy/*.rb` - Built-in strategies (ssh, github_pages)
- `lib/bard/provision/*.rb` - Server provisioning modules
- `spec/` - RSpec unit tests
- `features/` - Cucumber integration tests

## Testing Notes

- Use `focus: true` in RSpec to run specific tests
- Cucumber tests use testcontainers and are slow - run specific feature files only
- SimpleCov tracks coverage across both RSpec and Cucumber runs
