ruby_version, project_name = (`rvm current name`.chomp).split("@")

file ".ruby-version", ruby_version
file ".ruby-gemset", project_name

file "Gemfile", <<~RUBY
  source "https://rubygems.org"

  gem "bootsnap", require: false
  gem "rails", "~>8.0.0"
  gem "bard-rails"
  gem "sqlite3"

  gem "sprockets-rails"
  gem "dartsass-sprockets"
  gem "bard-sass"

  gem "importmap-rails"
  gem "turbo-rails"
  gem "stimulus-rails"

  gem "solid_cache"
  gem "solid_queue"
  gem "solid_cable"

  gem "image_processing"

  group :development do
    gem "web-console"
  end

  group :development, :test do
    gem "debug", require: "debug/prelude"
    gem "brakeman", require: false
    gem "rubocop-rails-omakase", require: false
  end

  group :test do
    gem "cucumber-rails", require: false
    gem "cuprite-downloads"
    gem "capybara-screenshot"
    gem "database_cleaner"
    gem "puma"
    gem "chop"
    gem "email_spec"
    gem "timecop"
    gem "rspec-rails"
  end

  group :production do
    gem "foreman-export-systemd_user"
  end
RUBY

file "app/assets/config/manifest.js", <<~RUBY
  //= link_tree ../images
  //= link_directory ../stylesheets .css
  //= link_tree ../../javascript .js
RUBY

run "rm -f app/assets/stylesheets/application.css"

file "app/assets/stylesheets/application.sass", <<~SASS
  body
    border: 10px solid red
SASS

gsub_file "app/views/layouts/application.html.erb", "    <%# Includes all stylesheet files in app/assets/stylesheets %>\n", ''
gsub_file "app/views/layouts/application.html.erb", 'stylesheet_link_tag :app,', 'stylesheet_link_tag :application,'

file "app/views/static/index.html.slim", <<~SLIM
  h1 #{project_name}
SLIM

insert_into_file "config/database.yml", <<~YAML, after: "database: storage/test.sqlite3"

  staging:
    <<: *default
    database: storage/staging.sqlite3
YAML

after_bundle do
  run "bard install"
  run "bin/setup"
  run "bard setup"
end

