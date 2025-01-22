ruby_version, project_name = (`rvm current name`.chomp).split("@")

file ".ruby-version", ruby_version
file ".ruby-gemset", project_name
file ".gitignore", <<~GITIGNORE
  # See https://help.github.com/articles/ignoring-files for more about ignoring files.
  #
  # If you find yourself ignoring temporary files generated by your text editor
  # or operating system, you probably want to add a global ignore instead:
  #   git config --global core.excludesfile '~/.gitignore_global'

  # Ignore bundler config.
  /.bundle

  # Ignore all logfiles and tempfiles.
  /log/*
  /tmp/*
  !/log/.keep
  !/tmp/.keep

  # Ignore master key for decrypting credentials and more.
  /config/master.key

  # ignore coverage reports
  /coverage

  # Ignore database dumps
  /db/data.*

  # Ignore storage (uploaded files in development and any SQLite databases).
  /storage/*

  # Ignore Syncthing
  .stfolder/

  # Thank Apple!
  .DS_Store
GITIGNORE

file "Gemfile", <<~RUBY
  source "https://rubygems.org"

  gem "bootsnap", require: false
  gem "rails", "~>8.0.0"
  gem "solid_cache"
  gem "solid_queue"
  gem "solid_cable"
  gem "bard-rails"
  gem "sqlite3"
  gem "image_processing"
  gem "puma"
  gem "exception_notification"

  # css
  gem "sprockets-rails"
  gem "dartsass-sprockets"
  gem "bard-sass"

  # js
  gem "importmap-rails"
  gem "turbo-rails"
  gem "stimulus-rails"

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
    gem "chop"
    gem "email_spec"
    gem "timecop"
    gem "rspec-rails"
  end

  group :production do
    gem "foreman-export-systemd_user"
  end
RUBY

file "config/initializers/exception_notification.rb", <<~RUBY
  require "exception_notification/rails"

  ExceptionNotification.configure do |config|
    config.ignored_exceptions = []

    # Adds a condition to decide when an exception must be ignored or not.
    # The ignore_if method can be invoked multiple times to add extra conditions.
    config.ignore_if do |exception, options|
      not Rails.env.production?
    end

    config.ignore_if do |exception, options|
      %w[
        ActiveRecord::RecordNotFound
        AbstractController::ActionNotFound
        ActionController::RoutingError
        ActionController::InvalidAuthenticityToken
        ActionView::MissingTemplate
        ActionController::BadRequest
        ActionDispatch::Http::Parameters::ParseError
        ActionDispatch::Http::MimeNegotiation::InvalidType
      ].include?(exception.class.to_s)
    end

    config.add_notifier :email, {
      email_prefix: "[\#{File.basename(Dir.pwd)}] ",
      exception_recipients: "micah@botandrose.com",
      smtp_settings: Rails.application.credentials.exception_notification_smtp_settings,
    }
  end

  if defined?(Rake::Application)
    Rake::Application.prepend Module.new {
      def display_error_message error
        ExceptionNotifier.notify_exception(error)
        super
      end

      def invoke_task task_name
        super
      rescue RuntimeError => exception
        if exception.message.starts_with?("Don't know how to build task")
          ExceptionNotifier.notify_exception(exception)
        end
        raise exception
      end
    }
  end

  ActionController::Live.prepend Module.new {
    def log_error exception
      ExceptionNotifier.notify_exception exception, env: request.env
      super
    end
  }
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

insert_into_file "config/database.yml", <<-YAML, after: "# database: path/to/persistent/storage/production.sqlite3"

  cable:
    <<: *default
    # database: path/to/persistent/storage/production_cable.sqlite3
    migrations_paths: db/cable_migrate
  queue:
    <<: *default
    # database: path/to/persistent/storage/production_queue.sqlite3
    migrations_paths: db/queue_migrate
YAML

gsub_file "config/environments/production.rb", /  (config\.logger.+STDOUT.*)$/, '  # \1'

after_bundle do
  run "bard install"
  run "bin/setup"
  run "bard setup"
end

