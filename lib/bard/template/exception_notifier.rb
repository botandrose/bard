require "bard/template/helper"

git :clone => "git://github.com/rails/exception_notification.git vendor/plugins/exception_notification"
inside "vendor/plugins/exception_notification" do
  git "checkout -b 2-3-stable origin/2-3-stable"
  run "rm -rf .git"
end

file_inject "app/controllers/application_controller.rb",
  "class ApplicationController < ActionController::Base", <<-END
  include ExceptionNotifiable

END

file_append "config/environment.rb", <<-END

ExceptionNotifier.exception_recipients = %w(micah@botandrose.com)
END

git :add => "."
git :commit => "-m'added exception notifier.'"
