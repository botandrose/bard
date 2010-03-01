Given /^a commit with a new migration$/ do
  type "script/generate migration test_migration"
  type "git add ."
  type "git commit -am'added test migration.'"
end

Given /^a (\w+) database$/ do |env|
  type "rake db:create RAILS_ENV=#{env} && rake db:migrate RAILS_ENV=#{env}"
end

Then /^the (\w+) database should include that migration$/ do |env|
  db_version = type("rake db:version RAILS_ENV=#{env}")[/[0-9]{14}/]
  migration_version = type("ls db/migrate/*_test_migration.rb")[/[0-9]{14}/]
  db_version.should == migration_version
end

Given /^the test gem is not installed$/ do
  type "gem uninstall rake-dotnet -v=0.0.1 -x"
end

Given /^a commit that adds the test gem as a dependency$/ do
  file_inject "config/environment.rb", "
Rails::Initializer.run do |config|", <<-RUBY
  config.gem "rake-dotnet", :version => "0.0.1"
RUBY
  type "git add ."
  type "git commit -am'added test gem dependency.'"
end

Then /^the test gem should be installed$/ do
  type("gem list rake-dotnet").should include "rake-dotnet (0.0.1)"
end

Then /^passenger should have been restarted$/ do
  File.exist?("tmp/restart.txt").should be_true
end

Given /^the "([^\"]+)" file includes "([^\"]+)"$/ do |file, contents|
  file_append file, contents
end

Given /^the "([^\"]+)" file does not include "([^\"]+)"$/ do |file, contents|
  gsub_file file, contents, ""
end
