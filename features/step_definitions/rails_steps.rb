Given /^I have committed a set of changes that includes a new migration$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    type "script/generate migration test_migration"
    type "git add ."
    type "git commit -am'added test migration.'"
  end
end

Given /^the remote integration branch has had a commit that includes a new migration$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do
    type "script/generate migration test_migration"
    type "git add ."
    type "git commit -am'added test migration.'"
  end
end

Given /^I have a development environment set up locally$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    type "rake db:create"
    type "rake db:migrate"
  end
end

Given /^the staging server has a staging and test environment set up$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do
    type "rake db:create RAILS_ENV=staging && rake db:create RAILS_ENV=test"
    type "rake db:migrate RAILS_ENV=staging && rake db:migrate RAILS_ENV=test"
  end
end

Given /^I have development and test environments set up locally$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    type "rake db:create && rake db:create RAILS_ENV=test"
    type "rake db:migrate && rake db:migrate RAILS_ENV=test"
  end
end

Then /^the development database should include that migration$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    db_version = type("rake db:version")[/[0-9]{14}/]
    test_migration_version = type("ls db/migrate/*_test_migration.rb")[/[0-9]{14}/]
    db_version.should == test_migration_version
  end
end

Then /^the both the staging and test databases should include that migration$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do
    staging_db_version = type("rake db:version RAILS_ENV=staging")[/[0-9]{14}/]
    test_db_version = type("rake db:version RAILS_ENV=test")[/[0-9]{14}/]
    test_migration_version = type("ls db/migrate/*_test_migration.rb")[/[0-9]{14}/]
    staging_db_version.should == test_migration_version
    test_db_version.should == test_migration_version
  end
end

Then /^both the development and test databases should include that migration$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    dev_db_version = type("rake db:version")[/[0-9]{14}/]
    test_db_version = type("rake db:version RAILS_ENV=test")[/[0-9]{14}/]
    test_migration_version = type("ls db/migrate/*_test_migration.rb")[/[0-9]{14}/]
    dev_db_version.should == test_migration_version
    test_db_version.should == test_migration_version
  end
end

Given /^I dont have the test gem installed$/ do
  type "gem uninstall rake-dotnet -v=0.0.1 -x"
end

Given /^I have committed a set of changes that adds the test gem as a dependency$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    file_inject "config/environment.rb", "
Rails::Initializer.run do |config|", <<-RUBY
  config.gem "rake-dotnet", :version => "0.0.1"
RUBY
    type "git add ."
    type "git commit -am'added test gem dependency.'"
  end
end

Given /^the remote integration branch has had a commit that adds the test gem as a dependency$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do
    file_inject "config/environment.rb", "
Rails::Initializer.run do |config|", <<-RUBY
  config.gem "rake-dotnet", :version => "0.0.1"
RUBY
    type "git add ."
    type "git commit -am'added test gem dependency.'"
  end
end

Then /^the test gem should be installed$/ do
  type("gem list rake-dotnet").should include "rake-dotnet (0.0.1)"
end

Then /^passenger should have been restarted$/ do
  File.exist?("tmp/restart.txt").should be_true
end

Then /^the staging passenger should have been restarted$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do
    File.exist?("tmp/restart.txt").should be_true
  end
end
