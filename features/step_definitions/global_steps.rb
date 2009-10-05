Given /^a shared rails project$/ do
  # TEARDOWN
  Dir.chdir ROOT
  type "rm -rf tmp"
  
  # SETUP
  Dir.chdir ROOT
  Dir.mkdir 'tmp'
  type "cp -R fixtures/repo tmp/origin"
  Dir.chdir 'tmp/origin' do
    File.open ".git/hooks/post-receive", "w" do |f|
      f.puts <<-BASH
#!/bin/bash
RAILS_ENV=staging #{ROOT}/bin/bard stage $@
BASH
      f.chmod 0775
    end
    type "cp config/database.yml.sample config/database.yml"
    type "git checkout -b integration"
  end
  type "cp -R fixtures/repo tmp/submodule"
  type "cp -R fixtures/repo tmp/submodule2"
  type "git clone tmp/origin tmp/local"
  Dir.chdir 'tmp/local'
  @repo = Grit::Repo.new "."
  type "grb fetch integration"
  type "git checkout integration"
  type "cp config/database.yml.sample config/database.yml"
end

When /^I type "([^\"]*)"$/ do |command|
  type command.sub /\b(bard)\b/, "#{ROOT}/bin/bard"
end

When /^I type "([^\"]*)" on the staging server$/ do |command|
  Dir.chdir "#{ROOT}/tmp/origin" do
    When %(I type "#{command}")
  end
end

Then /^I should see the fatal error "([^\"]*)"$/ do |error_message|
  @stderr.should include(error_message)
end

Then /^I should see the warning "([^\"]*)"$/ do |warning_message|
  @stderr.should include(warning_message) 
end

Then /^I should see "([^\"]*)"$/ do |message|
  @stdout.should include(message) 
end
