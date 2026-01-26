# Plugin Development

Bard uses a plugin system to extend functionality. Plugins can add CLI commands, target methods, and config DSL methods.

## Plugin Structure

Plugins live in `lib/bard/plugins/` and register themselves:

```ruby
# lib/bard/plugins/my_plugin.rb
require "bard/plugin"

Bard::Plugin.register :my_plugin do
  # Add CLI commands (class must implement .setup)
  cli "Bard::CLI::MyPlugin", require: "bard/cli/my_plugin"

  # Add methods to Target
  target_method :my_feature do |url = nil|
    if url.nil?
      @my_feature_url
    else
      @my_feature_url = url
      enable_capability(:my_feature)
    end
  end

  # Add methods to Config
  config_method :my_global_setting do |value = nil|
    if value.nil?
      @my_global_setting
    else
      @my_global_setting = value
    end
  end
end
```

## CLI Commands

CLI commands inherit from `Bard::CLI::Command` and implement a `setup` class method:

```ruby
# lib/bard/cli/my_plugin.rb
require "bard/cli/command"

class Bard::CLI::MyPlugin < Bard::CLI::Command
  desc "mycommand", "Description of my command"
  def mycommand
    puts "Hello from my plugin!"
  end
end
```

The `Command` base class provides:
- Automatic `setup` that registers the command with the CLI
- Delegation to the CLI instance (access to `config`, `project_name`, etc.)
- `desc` and `option` class methods for Thor integration

For Thor subcommand groups (nested under `bard mygroup`):

```ruby
# lib/bard/cli/my_subcommand.rb
class Bard::CLI::MySubcommand < Thor
  def self.setup(cli)
    cli.register(self, "mygroup", "mygroup COMMAND", "My subcommand group")
  end

  desc "action", "Do something"
  def action
    puts "Hello from subcommand!"
  end
end
```

## Adding Strategies

Plugins can add deployment strategies or CI runners:

```ruby
# Custom deploy strategy
module Bard
  class DeployStrategy
    class MyCloud < DeployStrategy
      def deploy
        # Deployment logic here
        run! "my-cloud deploy #{target.key}"
      end
    end
  end
end

# Custom CI runner
module Bard
  class CI
    class Runner
      class MyCI < Runner
        def run
          # Start CI run
        end

        def status
          # Return current status
        end
      end
    end
  end
end
```

Strategies auto-register via Ruby's `inherited` hook. The class name determines the strategy key (e.g., `MyCloud` → `:my_cloud`).

## Plugin Loading

Plugins are loaded automatically from `lib/bard/plugins/`. The load order is alphabetical by filename. For CI runners, the last registered runner becomes the default.
