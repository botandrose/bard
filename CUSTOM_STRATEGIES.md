# Custom Deployment Strategies Guide

This guide shows you how to create custom deployment strategies for Bard v2.0.

## Overview

Bard's deployment strategies are pluggable modules that define how code gets deployed. Built-in strategies include SSH and GitHub Pages, but you can create your own for any deployment target: Jets, Docker, Kubernetes, Heroku, AWS Lambda, etc.

## How Strategies Work

### Auto-Registration

Strategies automatically register themselves via Ruby's `inherited` hook. No manual registration needed!

```ruby
module Bard
  class DeployStrategy
    class MyStrategy < DeployStrategy
      # Automatically registered as :my_strategy
    end
  end
end
```

### DSL Integration

Once registered, your strategy becomes a DSL method:

```ruby
# After defining DeployStrategy::Jets
target :production do
  jets "https://api.example.com", run_tests: true
end
```

## Basic Strategy

### Minimal Example

```ruby
# lib/docker_deploy_strategy.rb
module Bard
  class DeployStrategy
    class Docker < DeployStrategy
      def deploy
        run! "docker build -t myapp ."
        run! "docker push myapp:latest"
        run! "docker stack deploy -c docker-compose.yml myapp"
      end
    end
  end
end
```

Use it:

```ruby
# bard.rb
require_relative 'lib/docker_deploy_strategy'

target :production do
  docker "https://app.example.com"
end
```

### What You Get

Your strategy class provides:

- `target` - The target being deployed
- `run!(cmd)` - Run local command (raises on error)
- `run(cmd)` - Run local command (silent on error)
- `system!(cmd)` - Run command with live output
- Access to target's capabilities via `target.run!`, `target.ssh`, etc.

## Strategy with Options

### Passing Options

Options passed to the DSL method are available via `target.strategy_options(name)`:

```ruby
module Bard
  class DeployStrategy
    class Jets < DeployStrategy
      def deploy
        options = target.strategy_options(:jets)

        run! "rake vips:build:#{target.key}" unless options[:skip_build]
        run! "bundle exec rspec" if options[:run_tests]
        run! "jets deploy #{options[:env] || target.key}"
      end
    end
  end
end
```

Use it:

```ruby
target :production do
  jets "https://api.example.com", run_tests: true, env: "prod"
end

target :staging do
  jets "https://staging-api.example.com", skip_build: true
end
```

## Strategy with Ping Configuration

### Auto-Configure Ping

Strategies can auto-configure ping URLs:

```ruby
module Bard
  class DeployStrategy
    class Jets < DeployStrategy
      def initialize(target, url, **options)
        super(target)
        @url = url
        @options = options

        # Auto-configure ping
        target.ping(url)
      end

      def deploy
        run! "jets deploy #{@options[:env] || target.key}"
      end
    end
  end
end
```

Now `bard ping production` and `bard open production` work automatically.

## Real-World Examples

### Example 1: Jets (AWS Lambda)

```ruby
# lib/jets_deploy_strategy.rb
module Bard
  class DeployStrategy
    class Jets < DeployStrategy
      def initialize(target, url, **options)
        super(target)
        @url = url
        @options = options
        target.ping(url)
      end

      def deploy
        target_name = target.key.to_s

        # Build static assets
        run! "rake vips:build:#{target_name}" unless @options[:skip_build]

        # Run tests
        if should_run_tests?(target_name)
          run! "bundle exec rspec"
        end

        # Deploy to AWS
        env = @options[:env] || target_name
        run! "jets deploy #{env}"

        # Smoke test
        target.ping! if @options[:verify]
      end

      private

      def should_run_tests?(target_name)
        return @options[:run_tests] if @options.key?(:run_tests)
        target_name == "production"  # Default: test production only
      end
    end
  end
end
```

Usage:

```ruby
# bard.rb
require_relative 'lib/jets_deploy_strategy'

target :staging do
  jets "https://staging-api.example.com",
    skip_build: true,
    run_tests: false
end

target :production do
  jets "https://api.example.com",
    run_tests: true,
    verify: true
end

backup false  # Serverless doesn't need backups
```

### Example 2: Heroku

```ruby
# lib/heroku_deploy_strategy.rb
module Bard
  class DeployStrategy
    class Heroku < DeployStrategy
      def initialize(target, app_name, **options)
        super(target)
        @app_name = app_name
        @options = options

        # Auto-configure ping from Heroku app name
        target.ping("https://#{app_name}.herokuapp.com")
      end

      def deploy
        # Push to Heroku
        remote = @options[:remote] || "heroku"
        run! "git push #{remote} HEAD:master"

        # Run migrations
        run! "heroku run rake db:migrate -a #{@app_name}" if @options[:migrate]

        # Restart
        run! "heroku restart -a #{@app_name}"

        # Smoke test
        target.ping!
      end
    end
  end
end
```

Usage:

```ruby
# bard.rb
require_relative 'lib/heroku_deploy_strategy'

target :staging do
  heroku "myapp-staging", migrate: true
end

target :production do
  heroku "myapp-production", migrate: true, remote: "production"
end
```

### Example 3: Kubernetes

```ruby
# lib/kubernetes_deploy_strategy.rb
module Bard
  class DeployStrategy
    class Kubernetes < DeployStrategy
      def initialize(target, url, **options)
        super(target)
        @url = url
        @options = options
        @namespace = options[:namespace] || target.key.to_s
        @context = options[:context]

        target.ping(url)
      end

      def deploy
        # Build and push Docker image
        tag = git_sha
        run! "docker build -t #{image_name}:#{tag} ."
        run! "docker push #{image_name}:#{tag}"

        # Update Kubernetes deployment
        kubectl "set image deployment/#{app_name} #{app_name}=#{image_name}:#{tag}"

        # Wait for rollout
        kubectl "rollout status deployment/#{app_name}"

        # Smoke test
        target.ping!
      end

      private

      def kubectl(cmd)
        context_flag = @context ? "--context #{@context}" : ""
        run! "kubectl #{context_flag} -n #{@namespace} #{cmd}"
      end

      def image_name
        @options[:image] || "myregistry/#{app_name}"
      end

      def app_name
        @options[:app] || target.key.to_s
      end

      def git_sha
        `git rev-parse --short HEAD`.strip
      end
    end
  end
end
```

Usage:

```ruby
# bard.rb
require_relative 'lib/kubernetes_deploy_strategy'

target :staging do
  kubernetes "https://staging.example.com",
    namespace: "staging",
    context: "minikube",
    image: "myregistry/myapp"
end

target :production do
  kubernetes "https://example.com",
    namespace: "production",
    context: "production-cluster",
    image: "myregistry/myapp"
end
```

### Example 4: Docker Compose

```ruby
# lib/docker_compose_deploy_strategy.rb
module Bard
  class DeployStrategy
    class DockerCompose < DeployStrategy
      def initialize(target, **options)
        super(target)
        @options = options
      end

      def deploy
        # Requires SSH capability for remote deployment
        target.require_capability!(:ssh)

        # Push code to server
        run! "git push origin #{branch}"

        # Pull and restart on remote server
        target.run! "cd #{target.path} && git pull origin #{branch}"
        target.run! "cd #{target.path} && docker-compose pull"
        target.run! "cd #{target.path} && docker-compose up -d"

        # Clean up old images
        target.run! "docker image prune -f" if @options[:prune]
      end

      private

      def branch
        @options[:branch] || "master"
      end
    end
  end
end
```

Usage:

```ruby
# bard.rb
require_relative 'lib/docker_compose_deploy_strategy'

target :production do
  ssh "deploy@example.com:22", path: "app"
  docker_compose branch: "main", prune: true
  ping "https://example.com"
end
```

## Advanced Patterns

### Strategy with CI Integration

```ruby
module Bard
  class DeployStrategy
    class CustomDeploy < DeployStrategy
      def deploy
        # Run CI if not disabled
        unless @options[:skip_ci]
          run! "bard ci"
        end

        # Deploy
        run! "my-deploy-command"
      end
    end
  end
end
```

### Strategy with Backup Support

```ruby
module Bard
  class DeployStrategy
    class CustomDeploy < DeployStrategy
      def deploy
        # Create backup if enabled
        if target.config.backup_enabled?
          target.run! "bin/rake db:backup"
        end

        # Deploy
        run! "my-deploy-command"
      end
    end
  end
end
```

### Strategy with Rollback

```ruby
module Bard
  class DeployStrategy
    class CustomDeploy < DeployStrategy
      def deploy
        begin
          run! "my-deploy-command"
          target.ping!
        rescue => e
          puts "Deployment failed, rolling back..."
          run! "my-rollback-command"
          raise
        end
      end
    end
  end
end
```

### Multi-Stage Strategy

```ruby
module Bard
  class DeployStrategy
    class CustomDeploy < DeployStrategy
      def deploy
        stages.each do |stage|
          puts "Running stage: #{stage}"
          send(stage)
        end
      end

      private

      def stages
        @options[:stages] || [:build, :test, :deploy, :verify]
      end

      def build
        run! "rake assets:precompile"
      end

      def test
        run! "rspec"
      end

      def deploy
        run! "my-deploy-command"
      end

      def verify
        target.ping!
      end
    end
  end
end
```

## Capability Requirements

### Requiring Capabilities

If your strategy requires certain capabilities, check for them:

```ruby
module Bard
  class DeployStrategy
    class CustomDeploy < DeployStrategy
      def deploy
        # Fail fast if SSH not configured
        target.require_capability!(:ssh)

        # Now safe to use SSH
        target.run! "my-command"
      end
    end
  end
end
```

### Optional Capabilities

```ruby
module Bard
  class DeployStrategy
    class CustomDeploy < DeployStrategy
      def deploy
        run! "my-deploy-command"

        # Use SSH for debugging if available
        if target.has_capability?(:ssh)
          target.run! "tail -n 50 logs/production.log"
        end
      end
    end
  end
end
```

## Testing Strategies

### Unit Testing

```ruby
# spec/jets_deploy_strategy_spec.rb
require 'spec_helper'
require_relative '../lib/jets_deploy_strategy'

RSpec.describe Bard::DeployStrategy::Jets do
  let(:target) { double('target', key: :production) }
  let(:strategy) { described_class.new(target, "https://api.example.com", run_tests: true) }

  describe '#deploy' do
    it 'runs tests for production' do
      expect(strategy).to receive(:run!).with("bundle exec rspec")
      expect(strategy).to receive(:run!).with(/jets deploy/)
      strategy.deploy
    end
  end
end
```

### Integration Testing

```ruby
# spec/integration/jets_deployment_spec.rb
require 'spec_helper'

RSpec.describe 'Jets deployment' do
  it 'deploys to staging' do
    # Load bard.rb
    config = Bard::Config.new

    # Get strategy
    target = config[:staging]
    strategy = target.deploy_strategy

    # Verify strategy type
    expect(strategy).to be_a(Bard::DeployStrategy::Jets)

    # Test deployment (in dry-run mode)
    expect { strategy.deploy }.not_to raise_error
  end
end
```

## Distribution

### In Your Project

Place custom strategies in `lib/` and require them in `bard.rb`:

```ruby
# lib/my_deploy_strategy.rb
module Bard
  class DeployStrategy
    class MyDeploy < DeployStrategy
      # ...
    end
  end
end

# bard.rb
require_relative 'lib/my_deploy_strategy'

target :production do
  my_deploy "https://example.com"
end
```

### As a Gem

Package your strategy as a gem for reuse across projects:

```ruby
# my_bard_strategy.gemspec
Gem::Specification.new do |spec|
  spec.name          = "bard-jets"
  spec.version       = "1.0.0"
  spec.authors       = ["Your Name"]
  spec.summary       = "Jets deployment strategy for Bard"

  spec.files         = Dir["lib/**/*"]

  spec.add_dependency "bard", "~> 2.0"
end

# lib/bard/jets.rb
require 'bard'

module Bard
  class DeployStrategy
    class Jets < DeployStrategy
      # ...
    end
  end
end
```

Use it:

```ruby
# Gemfile
gem 'bard-jets'

# bard.rb
require 'bard/jets'

target :production do
  jets "https://api.example.com"
end
```

## Best Practices

1. **Auto-configure ping URLs** - Makes `bard ping` and `bard open` work
2. **Fail fast** - Use `require_capability!` to check dependencies early
3. **Provide good defaults** - Make simple cases simple
4. **Accept options** - Allow customization via hash options
5. **Test thoroughly** - Unit test logic, integration test with real targets
6. **Document well** - Include usage examples in README
7. **Handle errors** - Provide clear error messages
8. **Support dry-run** - Add `--dry-run` option support if possible

## Debugging

### Enable Verbose Output

```ruby
def deploy
  puts "Deploying to #{target.key}..."
  puts "Options: #{@options.inspect}"

  run! "my-command"
end
```

### Dry-Run Mode

```ruby
def deploy
  if ENV['DRY_RUN']
    puts "Would run: my-deploy-command"
  else
    run! "my-deploy-command"
  end
end
```

Use it:
```bash
DRY_RUN=1 bard deploy production
```

## Getting Help

- Review [ARCHITECTURE.md](ARCHITECTURE.md) for v2 architecture details
- Review [README.md](README.md) for API documentation
- Check built-in strategies in `lib/bard/deploy_strategy/`
- Open an issue at https://github.com/botandrose/bard/issues

## Examples Repository

Find more examples at:
https://github.com/botandrose/bard-strategies

Includes:
- AWS Lambda (Jets)
- Heroku
- Docker Compose
- Kubernetes
- Google Cloud Run
- Azure App Service
- And more!
