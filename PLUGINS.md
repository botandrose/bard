# Plugin Development

Bard uses a plugin system to extend functionality. Plugins can add CLI commands, target methods, and config DSL methods.

## Plugin Structure

Plugins live in `lib/bard/plugins/` and are auto-loaded. Command classes auto-register when they subclass `Bard::Plugin::Command`:

```ruby
# lib/bard/plugins/my_plugin.rb
require "bard/plugin"

class Bard::CLI::MyPlugin < Bard::Plugin::Command
  desc "mycommand", "Description of my command"
  option :verbose, type: :boolean
  def mycommand
    puts "Hello from my plugin!"
    puts config[:production].url
  end
end
```

That's it — no registration block needed. The `Command` base class provides:
- Automatic registration via Ruby's `inherited` hook
- `desc` and `option` class methods for Thor integration
- Delegation to the CLI instance (access to `config`, `project_name`, `run!`, `options`, etc.)

## Extending Target and Config

To add methods to `Bard::Target` or `Bard::Config`, reopen the class directly:

```ruby
# lib/bard/plugins/my_plugin.rb
require "bard/target"

class Bard::Target
  def my_feature(url = nil)
    if url.nil?
      @my_feature_url
    else
      @my_feature_url = url
      enable_capability(:my_feature)
    end
  end
end

require "bard/config"

class Bard::Config
  def my_global_setting(value = nil)
    if value.nil?
      @my_global_setting
    else
      @my_global_setting = value
    end
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

Plugins are loaded automatically from `lib/bard/plugins/`. The load order is alphabetical by filename. External plugins are loaded from the project's `lib/bard/plugins/` directory.
