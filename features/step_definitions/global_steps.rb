Given /^a shared rails project$/ do
  # TEARDOWN
  Dir.foreach "#{ROOT}/tmp" do |file|
    FileUtils.rm_rf("#{ROOT}/tmp/#{file}") unless %w(fixtures . ..).include? file
  end

  # SETUP
  Dir.chdir ROOT
  `cp -r tmp/fixtures/* tmp/`

  Dir.chdir 'tmp'
  @repos = {}
  %w(development_a development_b staging production).each do |env|
    @repos[env] = Grit::Repo.new env
  end
  Dir.chdir 'development_a'
  @repo = @repos['development_a']
  @env = { 'RAILS_ENV' => 'development', 'TESTING' => true }
end

Given /^I am in a subdirectory$/ do
  FileUtils.mkdir "test_subdirectory"
  Dir.chdir "test_subdirectory"
end

When /^I type "([^\"]*)"$/ do |command|
  type command.sub /\b(bard)\b/, "#{ROOT}/bin/bard"
end

When /^on (\w+), (.*$)/ do |env, step|
  old_env = @env['RAILS_ENV']
  @env['RAILS_ENV'] = env if %w(staging production).include? env
  Dir.chdir "#{ROOT}/tmp/#{env}" do
    old_repo = @repo
    @repo = @repos[env]
    When step
    @repo = old_repo
  end
  @env['RAILS_ENV'] = old_env
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

Then /^debug$/ do
  debugger
end
