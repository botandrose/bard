Given /^the remote integration branch has had a commit that includes a new migration$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do
    type "cp config/database.yml.sample config/database.yml"
    type "git checkout integration"
    type "script/generate migration test_migration"
    type "git add ."
    type "git commit -am'added test migration.'"
  end
end

Given /^I have development and test environments set up locally$/ do
  Dir.chdir "#{ROOT}/tmp/local" do
    type "cp config/database.yml.sample config/database.yml"
    type "rake db:create && rake db:create RAILS_ENV=test"
    type "rake db:migrate && rake db:migrate RAILS_ENV=test"
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

Given /^the remote integration branch has had a commit that includes a gem dependency change$/ do
  pending
end

Then /^I should see that "([^\"]*)" has been run$/ do |arg1|
  pending
end

