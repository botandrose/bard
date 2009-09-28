Given /^a shared test project$/ do
  Dir.mkdir 'tmp' rescue Errno::EEXIST
  Dir.chdir 'tmp'
  `rm -rf bard_test_fixture`
  `git clone staging@staging.botandrose.com:bard_test_fixture`
  Dir.chdir 'bard_test_fixture'
  @repo = Grit::Repo.new "."
end

When /^I type "([^\"]*)"$/ do |command|
  @status, @stdout, @stderr = systemu command
end

Then /^I should be on the "([^\"]*)" branch$/ do |branch|
  @repo.head.name.should == branch
end

Then /^the "([^\"]*)" branch should match the "([^\"]*)" branch$/ do |local_branch, remote_branch|
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_branch).first.id
  local_sha.should == remote_sha
end

Given /^a dirty working directory$/ do
  FileUtils.touch "new_file"
end

Then /^I should see the fatal error "([^\"]*)"$/ do |error_message|
  @stderr.should include(error_message)
end

Then /^there should not be a "([^\"]*)" branch$/ do |branch_name|
  @repo.branches.any? { |branch| branch.name == branch_name }
end
