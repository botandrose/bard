# Bard 2.0.0 Architecture

## Vision

A modular deployment tool where:
- **Core** provides minimal git workflow and configuration
- **Capabilities** are enabled via DSL methods
- **Deployment strategies** are pluggable and auto-registered
- **Subsystems** are independent and composable

## Core Concepts

### Target
A deployment destination. Targets are strategy-agnostic and capability-based.

### Capability
A feature enabled on a target (e.g., SSH, database, file copying, CI).

### Deployment Strategy
How code gets deployed to a target. Strategies are pluggable and auto-register via `inherited` hook.

## Subsystems

### 1. Core (always enabled)
**Files:**
- `lib/bard/config.rb` - Configuration DSL
- `lib/bard/target.rb` - Target (formerly Server) definition
- `lib/bard/git.rb` - Git utilities
- `lib/bard/cli.rb` - CLI framework
- `lib/bard/deploy_strategy.rb` - Base strategy class with auto-registration
- `lib/bard/default_config.rb` - Default target configurations

**Responsibilities:**
- Load default configuration
- Load and evaluate `bard.rb` (overrides defaults)
- Provide target registry
- Git workflow (branching, merging, fast-forward checks)
- Deployment strategy auto-registration

**DSL:**
```ruby
target :production do
  # DSL methods enable capabilities
end
```

**Commands:**
- `bard deploy` - Core git workflow + delegates to strategy
- `bard hurt` - Show uncommitted changes (git-based, no target needed)
- `bard vim` - Open changed files in vim (git-based, no target needed)

**Default Targets:**
Defined in `lib/bard/default_config.rb` (can be overridden in `bard.rb`):
- `:local` - No SSH, path `./`, ping `#{project_name}.local`
- `:ci` - Jenkins at `staging.botandrose.com`
- `:staging` - SSH to `staging.botandrose.com`
- `:gubs` - SSH to Bot and Rose cloud server

---

### 2. SSH Capability
**Files:**
- `lib/bard/ssh_server.rb` - SSH connection abstraction
- `lib/bard/command.rb` - Remote command execution
- `lib/bard/copy.rb` - SCP/rsync file transfer

**Enabled by:**
```ruby
target :production do
  ssh "user@host:port",
    path: "deploy/path",
    gateway: "bastion@host:port",
    ssh_key: "/path/to/key",
    env: "RAILS_ENV=production"
end
```

**Provides:**
- `target.server` - Access to SSHServer object
- `target.run!(cmd)` - Execute remote command
- `target.run(cmd)` - Execute remote command (no exception on failure)
- `target.exec!(cmd)` - Replace current process with remote command
- `target.copy_file(path, to:)` - Copy file to another target
- `target.copy_dir(path, to:)` - Rsync directory to another target

**Commands enabled:**
- `bard ssh [target]` - SSH into target
- `bard run [target] "command"` - Run command on target

**Auto-configuration:**
- Sets ping URL from hostname

**Error handling:**
- Commands that require SSH fail with clear message if capability not enabled

---

### 3. Deployment Strategies

#### SSH Strategy (built-in)
**File:** `lib/bard/deploy_strategy/ssh.rb`

**Enabled by:**
```ruby
target :production do
  ssh "user@host:port"
end
```

**Deployment behavior:**
1. Runs `git pull origin master && bin/setup` on remote server

**Requires:** SSH capability

---

#### GitHub Pages Strategy (built-in)
**File:** `lib/bard/deploy_strategy/github_pages.rb`

**Enabled by:**
```ruby
target :production do
  github_pages "https://example.com"
end
```

**Deployment behavior:**
1. Starts Rails server locally
2. Mirrors site with wget
3. Creates orphan commit with static assets
4. Force-pushes to `gh-pages` branch

**Requires:** None (runs locally)

---

#### Custom Strategies (user-defined)
**Example:** Jets deployment (lives in crucible project)

```ruby
# In crucible project: lib/jets_deploy_strategy.rb
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

**Usage:**
```ruby
# In crucible/bard.rb
require_relative 'lib/jets_deploy_strategy'

target :production do
  jets "https://api.example.com", run_tests: true
end
```

**Auto-registered:** ✅ Via `DeployStrategy.inherited` hook

---

### 4. CI Capability
**Files:**
- `lib/bard/ci.rb` - CI abstraction
- `lib/bard/ci/local.rb` - Local test runner
- `lib/bard/ci/jenkins.rb` - Jenkins integration
- `lib/bard/ci/github_actions.rb` - GitHub Actions integration

**Auto-enabled:** Based on detection:
- `.github/workflows/ci.yml` exists → GitHub Actions
- Otherwise → Jenkins (legacy)

**Override via DSL:**
```ruby
# Force specific CI system
ci :github_actions
ci :jenkins
ci :local

# Disable CI
ci false
```

**Commands:**
- `bard ci [branch]` - Run CI checks
  - `--local-ci` - Run tests locally
  - `--status` - Check CI status
  - `--resume` - Resume existing CI build

**Used by:** `bard deploy` (unless `--skip-ci`)

---

### 5. Data Capability
**Files:**
- `lib/bard/cli/data.rb` - Data sync command

**Enabled by:**
Database syncing is enabled by default, provided that SSH capability exists on both source and destination targets. The `data` DSL configures additional file paths to sync with rsync.
```ruby
# Global configuration (applies to all targets)
data "public/uploads", "public/system"
```

**Commands enabled:**
- `bard data --from=production --to=local` - Copy database and assets

**Behavior:**
1. Runs `bin/rake db:dump` on source target
2. Copies `db/data.sql.gz` via SCP
3. Runs `bin/rake db:load` on destination target
4. Rsyncs each configured data path if configured

**Requires:**
- SSH capability on both source and destination targets

**Opitional:**
- Additional data paths to rsync configured via `data` DSL

**Safety:**
- Warns when pushing to production
- Requires confirmation with full production URL

---

### 6. Backup Capability
**Enabled by:**
```ruby
# Global configuration
backup true   # Enable backups (default for SSH deployments)
backup false  # Disable backups (typical for serverless/static)
```

**Purpose:**
Controls whether database backups are created during deployment/provisioning.

**Used by:**
- Deployment process
- Provisioning scripts

**Separate from:** Data capability (backup is about creating backups, data is about syncing)

**Requires:** SSH capability (backups are stored on remote servers)

---

### 7. Master Key Capability
**Files:**
- `lib/bard/cli/master_key.rb` - Master key sync

**Commands:**
- `bard master_key --from=production --to=local` - Copy Rails master key

**Behavior:**
- Copies `config/master.key` via SCP between targets

**Requires:** SSH capability on both source and destination targets

**Used by:**
- `bard provision` (initial setup)
- Manual key distribution

---

### 8. Staging Capability
**Commands:**
- `bard stage [branch]` - Deploy feature branch to staging without merge

**Behavior:**
1. Pushes branch to origin
2. Checks out branch on staging server via SSH
3. Runs `bin/setup`
4. Pings staging

**Requires:**
- SSH capability on `:staging` target
- `:production` target must be defined (otherwise use `bard deploy staging`)

---

### 9. Ping Capability
**Enabled by:**
```ruby
target :production do
  ping "https://example.com"
  ping "/health", "/status"  # Multiple paths
end
```

**Auto-enabled by:** Deployment strategies that provide URLs

**Commands:**
- `bard ping [target]` - Check if URLs respond

**Behavior:**
- Makes HTTP requests to ping URLs
- Follows redirects
- Exits with error if any URL is down

**Used by:** `bard deploy` (after successful deployment)

---

### 10. Provisioning (Separate Command)
**Files:**
- `lib/bard/provision.rb` - Provision orchestration
- `lib/bard/provision/*.rb` - Individual provisioning steps

**Commands:**
- `bard setup` - Configure nginx for current app
- `bard provision [ssh_url]` - Full server provisioning

**Provisioning steps:**
1. SSH - Configure SSH access
2. User - Create deployment user
3. AuthorizedKeys - Install SSH keys
4. Swapfile - Create swap
5. Apt - Install system packages
6. MySQL - Install and configure MySQL
7. Repo - Clone git repository
8. MasterKey - Install Rails master key
9. RVM - Install Ruby
10. App - Bundle and setup app
11. Passenger - Install Passenger
12. HTTP - Configure nginx
13. LogRotation - Configure log rotation
14. Data - Import initial data (if backup enabled)
15. Deploy - Initial deployment

**Requires:** SSH capability on target

**Note:** Provisioning is a one-time server setup command, not a deployment capability

---

### 11. Open Capability
**Commands:**
- `bard open [target]` - Open target URL in browser

**Behavior:**
- Uses `ping` URL from target configuration
- Opens in system default browser

**Requires:** Ping URL configured on target

---

## Capability Dependency Tree

```
Core (always enabled)
├── Git workflow
├── Target registry
└── Strategy auto-registration

SSH Capability
├── Enables: run!, run, exec!, copy_file, copy_dir
├── Required by: SSH strategy, backup, data, master_key, provisioning
└── Commands: bard ssh, bard run

CI Capability
├── Auto-detected (github actions / jenkins)
├── Overridable via DSL
└── Used by: bard deploy (unless --skip-ci)

Data Capability
├── Requires: SSH on both targets
└── Commands: bard data

Backup Capability
├── Requires: SSH
└── Used by: deployment, provisioning

Master Key Capability
├── Requires: SSH on both targets
└── Commands: bard master_key

Ping Capability
├── Auto-configured by deployment strategies
└── Commands: bard ping, bard open

Deployment Strategies
├── SSH: requires SSH capability
├── GitHub Pages: no requirements
└── Custom (Jets, Docker, etc.): defined by user
```

---

## Modular Architecture

### Capability Registration

Capabilities are enabled implicitly via DSL methods:

```ruby
# Enable SSH capability
ssh "user@host"

# Enable GitHub Pages deployment
github_pages "https://example.com"

# Enable data sync
data "public/uploads"

# Enable/disable backups
backup true
```

### Capability Detection

Commands check for capabilities before executing:

```ruby
# In bard/cli/data.rb
def data
  from = config[options[:from]]
  to = config[options[:to]]

  # Will raise "SSH not configured for this target" if capability missing
  from.run! "bin/rake db:dump"
  from.copy_file "db/data.sql.gz", to: to
  to.run! "bin/rake db:load"

  # Only sync if data paths configured
  config.data.each do |path|
    from.copy_dir path, to: to
  end
end
```

### Strategy Auto-Registration

```ruby
# In lib/bard/deploy_strategy.rb
class DeployStrategy
  @strategies = {}

  def self.inherited(subclass)
    name = extract_strategy_name(subclass)
    strategies[name] = subclass
  end
end

# User defines custom strategy
class DeployStrategy::Docker < DeployStrategy
  def deploy
    # ...
  end
end
# Automatically registers as :docker strategy
```

### Dynamic DSL Methods

```ruby
# In lib/bard/target.rb
def method_missing(method, *args, **kwargs)
  if Bard::DeployStrategy[method]
    enable_strategy(method, *args, **kwargs)
  else
    super
  end
end
```

This allows any registered strategy to be used as a DSL method without modifying Target class.

### Default Configuration

```ruby
# lib/bard/default_config.rb
module Bard
  DEFAULT_CONFIG = proc do |project_name|
    target :local do
      ssh false
      path "./"
      ping "#{project_name}.local"
    end

    target :ci do
      ssh "jenkins@staging.botandrose.com:22022"
      path "jobs/#{project_name}/workspace"
      ping false
    end

    target :staging do
      ssh "www@staging.botandrose.com:22022"
      path project_name
      ping "#{project_name}.botandrose.com"
    end

    target :gubs do
      ssh "botandrose@cloud.hackett.world:22022"
      path "Sites/#{project_name}"
      ping false
    end
  end
end
```

Loaded before user's `bard.rb`, so user can override any default target.

---

## Migration Path (1.x → 2.0.0)

### Breaking Changes

1. **`server` renamed to `target`**
   - Rationale: More accurate for serverless deployments
   - Migration: `server` is aliased to `target` for compatibility (deprecated)

2. **SSH configuration changes**
   ```ruby
   # Old (1.x)
   server :production do
     ssh "user@host:port"
     path "deploy/path"
     gateway "bastion@host:port"
   end

   # New (2.0)
   target :production do
     ssh "user@host:port",
       path: "deploy/path",
       gateway: "bastion@host:port"
   end
   ```

3. **Strategy-first configuration**
   ```ruby
   # Old (1.x)
   server :production do
     github_pages true
     ping "https://example.com"
   end

   # New (2.0)
   target :production do
     github_pages "https://example.com"  # Sets both strategy and ping
   end
   ```

### Deprecation Warnings

Version 1.9.x can include deprecation warnings for:
- Using `server` instead of `target`
- Old-style SSH configuration
- Old-style strategy configuration

---

## Benefits of New Architecture

1. **Modularity**: Capabilities are independent and composable
2. **Extensibility**: Custom deployment strategies without gem modification
3. **Clarity**:
   - `target` vs `server` distinction
   - Clear capability dependencies (e.g., "data requires SSH")
4. **Auto-registration**: Strategies register themselves via Ruby's `inherited` hook
5. **Type safety**: Commands fail fast with clear messages if capability not enabled
6. **Flexibility**: Mix capabilities (e.g., Jets + SSH for debugging)
7. **Simplicity**: Default case is concise and clear
8. **Organization-specific**: Ships with Bot and Rose defaults, easily overridden

---

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
  ssh "deploy@bastion.example.com:22"  # Enables SSH commands for debugging
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
# Override default staging configuration
target :staging do
  jets "https://staging-api.example.com"
end

# Keep default :ci, :gubs, :local targets as-is
```

### Custom CI Configuration
```ruby
# Force local CI (ignore GitHub Actions)
ci :local

# Or disable CI entirely
ci false
```

---

## Implementation Checklist

### Phase 1: Documentation (Write the Spec)
**Goal:** Document the v2.0.0 API completely before implementation

- [ ] Update README.md with v2 API (already done)
- [ ] Finalize ARCHITECTURE.md (this file)
- [ ] Create MIGRATION_GUIDE.md (v1 → v2)
  - [ ] Document all breaking changes
  - [ ] Provide migration examples for each change
  - [ ] Include automated migration scripts if possible
- [ ] Document custom strategy creation
  - [ ] Step-by-step guide
  - [ ] Example implementations (Docker, Kubernetes, etc.)
  - [ ] Auto-registration explanation
- [ ] Document capability dependencies
  - [ ] Capability dependency tree diagram
  - [ ] Error messages for missing capabilities
- [ ] Add examples for all common use cases
  - [ ] Traditional Rails app
  - [ ] Serverless (Jets, Lambda)
  - [ ] Static sites (GitHub Pages)
  - [ ] Hybrid deployments
- [ ] Document default targets and how to override

**Success criteria:**
- Documentation is comprehensive and clear
- All v2 features are documented
- Migration path is well-explained
- Examples cover common use cases

---

### Phase 2: Testing (TDD - Write Failing Tests)
**Goal:** Write comprehensive tests that define v2.0.0 behavior

- [ ] Test capability system
  - [ ] Capabilities are enabled by DSL methods
  - [ ] Capabilities are checked before command execution
  - [ ] Clear error messages when capability missing
- [ ] Test strategy auto-registration
  - [ ] Strategies auto-register via `inherited` hook
  - [ ] Strategy name extraction from class name
  - [ ] Strategy retrieval from registry
- [ ] Test dynamic DSL methods
  - [ ] `method_missing` enables strategies
  - [ ] Auto-configuration of ping URLs
  - [ ] Strategy options storage
- [ ] Test default configuration
  - [ ] Defaults load before user config
  - [ ] User can override defaults
  - [ ] Default targets work as expected
- [ ] Test Target (formerly Server)
  - [ ] `target` DSL method creates targets
  - [ ] `server` DSL method works with deprecation (v1.9.x)
  - [ ] SSH configuration with hash options
  - [ ] Capability tracking
- [ ] Test SSH capability
  - [ ] SSHServer creation
  - [ ] run!, run, exec! methods
  - [ ] copy_file, copy_dir methods
  - [ ] Error when SSH not configured
- [ ] Test deployment strategies
  - [ ] SSH strategy requires SSH capability
  - [ ] GitHub Pages strategy runs locally
  - [ ] Custom strategy auto-registers
- [ ] Test data capability
  - [ ] Database sync works with SSH
  - [ ] Additional paths sync if configured
  - [ ] Error when SSH missing on source/destination
- [ ] Test CI capability
  - [ ] Auto-detection (GitHub Actions vs Jenkins)
  - [ ] Manual override via DSL
  - [ ] Disable via `ci false`
- [ ] Integration tests
  - [ ] Full deployment workflows
  - [ ] Multi-target data copying
  - [ ] Strategy-specific deployments

**Success criteria:**
- All tests fail (features not implemented yet)
- Tests clearly define expected behavior
- Edge cases are covered
- Error scenarios are tested

---

### Phase 3: Core Refactoring
**Goal:** Implement core v2.0.0 architecture

- [ ] Rename `Server` to `Target`
  - [ ] Create `lib/bard/target.rb`
  - [ ] Migrate code from `lib/bard/server.rb`
  - [ ] Keep `server.rb` as alias for compatibility
- [ ] Implement capability tracking system
  - [ ] `enable_capability(name)` method
  - [ ] `has_capability?(name)` method
  - [ ] `require_capability!(name)` with clear errors
- [ ] Add `DeployStrategy` base class with auto-registration
  - [ ] Create `lib/bard/deploy_strategy.rb`
  - [ ] Implement `inherited` hook for auto-registration
  - [ ] Strategy name extraction from class name
  - [ ] Strategy registry (`DeployStrategy.strategies`)
- [ ] Extract default configuration
  - [ ] Create `lib/bard/default_config.rb`
  - [ ] Move default targets from Config initialization
  - [ ] Load defaults before user config
- [ ] Update `Config` class
  - [ ] Load default config first
  - [ ] Then load user `bard.rb`
  - [ ] Support `target` DSL method
  - [ ] Keep `server` alias with deprecation

**Success criteria:**
- Tests for core features pass
- Capability tracking works
- Strategies auto-register
- Default config can be overridden

---

### Phase 4: SSH Capability
**Goal:** Refactor SSH into a capability

- [ ] Extract SSH connection to `SSHServer` class
  - [ ] Create `lib/bard/ssh_server.rb`
  - [ ] Move SSH-specific methods from Target
  - [ ] URI parsing and connection strings
- [ ] Update `ssh` DSL method
  - [ ] Accept hash options (path, gateway, ssh_key, env)
  - [ ] Create SSHServer instance
  - [ ] Enable SSH capability
  - [ ] Auto-configure ping from hostname
- [ ] Add capability checks
  - [ ] `run!` requires SSH capability
  - [ ] `copy_file` requires SSH capability
  - [ ] `copy_dir` requires SSH capability
  - [ ] Clear error messages when SSH missing
- [ ] Update commands to check SSH capability
  - [ ] `bard ssh` requires SSH
  - [ ] `bard run` requires SSH
  - [ ] Error message: "SSH not configured for this target"

**Success criteria:**
- SSH tests pass
- SSH is properly isolated as a capability
- Error messages are clear
- Commands fail gracefully without SSH

---

### Phase 5: Strategy Extraction
**Goal:** Extract deployment strategies into separate classes

- [ ] Create `DeployStrategy::SSH`
  - [ ] Move SSH deployment logic
  - [ ] `git pull origin master && bin/setup`
  - [ ] Require SSH capability
- [ ] Create `DeployStrategy::GithubPages`
  - [ ] Move GitHub Pages deployment logic
  - [ ] Static site building
  - [ ] Git commit and push to gh-pages
- [ ] Update `deploy.rb` to use strategy registry
  - [ ] Look up strategy from registry
  - [ ] Instantiate and call `deploy`
  - [ ] Error if strategy not found
- [ ] Add `method_missing` to Target
  - [ ] Check if method is registered strategy
  - [ ] Enable capability and set deploy_strategy
  - [ ] Store options for strategy
  - [ ] Auto-configure ping URL

**Success criteria:**
- Strategy tests pass
- Deployment strategies are isolated
- Dynamic DSL methods work
- Custom strategies can be registered

---

### Phase 6: Capability Commands
**Goal:** Update all commands to be capability-aware

- [ ] Update `data` command
  - [ ] Database sync always available with SSH
  - [ ] `data` DSL only adds optional file paths
  - [ ] Check SSH capability on source and destination
  - [ ] Clear error when SSH missing
- [ ] Update `master_key` command
  - [ ] Require SSH on source and destination
  - [ ] Clear error when SSH missing
- [ ] Update `backup` capability
  - [ ] Separate from `data`
  - [ ] Controls whether backups are created
  - [ ] Requires SSH (backups stored on servers)
- [ ] Add CI configuration DSL
  - [ ] `ci :github_actions` - force GitHub Actions
  - [ ] `ci :jenkins` - force Jenkins
  - [ ] `ci :local` - run locally
  - [ ] `ci false` - disable CI
  - [ ] Auto-detect by default
- [ ] Update all remaining commands
  - [ ] `bard stage` requires SSH on staging
  - [ ] `bard ping` requires ping URLs
  - [ ] `bard open` requires ping URLs
  - [ ] `bard provision` requires SSH
- [ ] Add clear error messages
  - [ ] "SSH not configured for this target"
  - [ ] "Ping URL not configured for this target"
  - [ ] "CI is disabled for this project"

**Success criteria:**
- All capability tests pass
- Commands check capabilities properly
- Error messages are helpful
- No regressions in functionality

---

### Phase 7: v1.9.x Transitional Release (Dual API Support)
**Goal:** Support both v1 and v2 APIs simultaneously with deprecation warnings

- [ ] Add deprecation warning infrastructure
- [ ] Support both `server` and `target` DSL methods
  - [ ] `target` is the new primary method
  - [ ] `server` calls `target` with deprecation warning
- [ ] Support both old and new SSH configuration styles
  ```ruby
  # v1 style (deprecated, still works)
  target :production do
    ssh "user@host:port"
    path "deploy/path"
    gateway "bastion@host"
  end

  # v2 style (preferred)
  target :production do
    ssh "user@host:port", path: "deploy/path", gateway: "bastion@host"
  end
  ```
- [ ] Support both old and new github_pages configuration
  ```ruby
  # v1 style (deprecated, still works)
  target :production do
    github_pages true
    ping "https://example.com"
  end

  # v2 style (preferred)
  target :production do
    github_pages "https://example.com"
  end
  ```
- [ ] Add deprecation warnings that guide users to v2 API
- [ ] Update CHANGELOG with deprecation notices
- [ ] Release v1.9.0 with dual API support

**Success criteria:**
- All existing projects work without changes
- Deprecation warnings guide users to new API
- v2 API is fully functional alongside v1 API

---

### Phase 8: v2.0.0 Release
**Goal:** Release v2.0.0 with v1 API removed

- [ ] Remove v1 API compatibility code
  - [ ] Remove `server` alias (breaking change)
  - [ ] Remove old-style SSH configuration support
  - [ ] Remove old-style strategy configuration
- [ ] Turn deprecation warnings into errors (if v1 API used)
- [ ] Update CHANGELOG with all breaking changes
- [ ] Ensure all tests pass
- [ ] Release v2.0.0

**Success criteria:**
- Only v2 API supported
- All tests pass
- Documentation is up to date
- CHANGELOG documents all changes

---

## Success Metrics

- [ ] Crucible successfully uses Jets deployment strategy
- [ ] Existing projects work with minimal bard.rb changes
- [ ] Documentation is clear and comprehensive
- [ ] Custom strategies can be created without modifying gem
- [ ] All tests pass
- [ ] No regressions in existing functionality
- [ ] Clear error messages when capabilities missing
- [ ] Default targets work as expected and can be overridden
