require "bard/template/helper"

# Testing Environment
with_options :env => :cucumber do
  gem 'cucumber',    :lib => false, :version => '0.4.3'
  gem 'webrat',      :lib => false, :version => '0.5.3'
  gem 'rspec',       :lib => false, :version => '1.2.9'
  gem 'rspec-rails', :lib => false, :version => '1.2.9'
  gem 'faker', :version => '0.3.1'
  gem "email_spec", :version => "0.4.0", :lib => false
  gem "machinist", :version => "1.0.6", :lib => false
  gem "pickle", :version => "0.2.1", :lib => false
end

plugin 'cucumber_rails_debug', :git => "git://github.com/mischa/cucumber_rails_debug"

generate "rspec"
generate "cucumber"
generate "email_spec"
generate "pickle"

file "features/support/blueprints.rb", <<-END
require 'machinist/active_record'
require 'faker'

Sham.name { Faker::Name.name }
Sham.email { Faker::Internet.email }
Sham.sentence { Faker::Lorem.sentence }
Sham.paragraph { Faker::Lorem.paragraph }
Sham.url { "http://\#{Faker::Internet.domain_name}/\#{Faker::Lorem.words(3).join('_').downcase}" }

Sham.address { Faker::Address.street_address }
Sham.city { Faker::Address.city }
Sham.zip { Faker::Address.zip_code }
Sham.phone { Faker::PhoneNumber.phone_number }
END
run "ln -s features/support/blueprints.rb spec/blueprints.rb"

file "features/support/debug.rb", <<-END
require 'ruby-debug'
require 'cucumber_rails_debug/steps'
END

file "features/support/email.rb", <<-END
# Email testing helpers
require 'email_spec/cucumber'
END

run "rake db:create RAILS_ENV=test"

git :add => "."
git :commit => "-m'added rspec and cucumber setups.'"

run "cap stage"
run "cap staging:bootstrap:ci"
