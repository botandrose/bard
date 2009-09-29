Given /^a shared rails project$/ do
  # TEARDOWN
  Dir.chdir ROOT
  type "rm -rf tmp"
  
  # SETUP
  Dir.chdir ROOT
  Dir.mkdir 'tmp'
  type "cp -R fixtures/repo tmp/origin"
  type "cp -R fixtures/repo tmp/submodule"
  type "cp -R fixtures/repo tmp/submodule2"
  type "git clone tmp/origin tmp/local"
  Dir.chdir 'tmp/local'
  @repo = Grit::Repo.new "."
  type "git checkout -b integration"
  type "grb share integration"
end

When /^I type "([^\"]*)"$/ do |command|
  type command
end

Then /^I should see the fatal error "([^\"]*)"$/ do |error_message|
  @stderr.should include(error_message)
end

Then /^I should see the warning "([^\"]*)"$/ do |warning_message|
  @stderr.should include(warning_message) 
end
