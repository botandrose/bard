# bard

The config core of the bard toolchain: the `bard.rb` DSL parser plus the target and SSH primitives everything else is built upon.

## What's here

- `Bard::Config` — parses `bard.rb`
- `Bard::Target` / `Bard::SSHServer` — deployment targets and connection details
- `Bard::Command` — SSH command execution
- the `ssh` / `ping` / `url` / `data` / `github_pages` / `ci` DSL declarations

## Development

```bash
bundle install
bundle exec rspec
```
