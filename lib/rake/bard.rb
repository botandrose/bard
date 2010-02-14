task :bootstrap do
  `git submodule update --init` if `git submodule` =~ /^[^ ]/
  `cp config/database.sample.yml config/database.yml` unless File.exist?('config/database.yml')
  `rake gems:install db:create RAILS_ENV=test`
  `rake gems:install db:create RAILS_ENV=cucumber`
end

Rake::Task[:default].clear
desc "Bootstrap the current project and run the tests."
task :default => [:bootstrap, :spec, :cucumber]
