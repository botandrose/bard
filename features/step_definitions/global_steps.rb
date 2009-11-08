Given /^a shared rails project$/ do
  # TEARDOWN
  Dir.foreach "#{ROOT}/tmp" do |file|
    FileUtils.rm_rf("#{ROOT}/tmp/#{file}") unless %w(fixtures . ..).include? file
  end
  
  # SETUP
  Dir.chdir ROOT
  `cp -r tmp/fixtures/* tmp/`
  Dir.chdir 'tmp/local'
  @repo = Grit::Repo.new "."

end

Given /^I am in a subdirectory$/ do
  FileUtils.mkdir "test_subdirectory"
  Dir.chdir "test_subdirectory"
end

When /^I type "([^\"]*)"$/ do |command|
  type command.sub /\b(bard)\b/, "#{ROOT}/bin/bard"
end

When /^on staging, (.*$)/ do |step|
  Dir.chdir "#{ROOT}/tmp/origin" do
    When step
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
