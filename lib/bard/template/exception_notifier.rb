require "bard/template/helper"

git :clone => "git://github.com/rails/exception_notification.git --branch=2-3-stable vendor/plugins/exception_notification"
run "rm -rf vendor/plugins/exception_notification/.git"

file_inject "app/controllers/application_controller.rb",
  "class ApplicationController < ActionController::Base", <<-END
  include ExceptionNotifiable

END

file_append "config/environment.rb", <<-END

ExceptionNotifier.exception_recipients = %w(micah@botandrose.com)
END

git :add => "."
git :commit => "-m'added exception notifier.'"