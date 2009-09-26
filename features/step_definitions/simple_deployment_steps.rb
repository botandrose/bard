

Given /^a shared test project$/ do
  `rm -rf bard_test_fixture`
  `git clone staging@staging.botandrose.com:bard_test_fixture`
  Dir.chdir 'bard_test_fixture'
  @repo = Grit::Repo.new "."
end

When /^I type "([^\"]*)"$/ do |command|
  system command
end

Then /^I should be on the "([^\"]*)" branch$/ do |branch|
  @repo.head.name.should == branch
end

Then /^the "([^\"]*)" branch should match the "([^\"]*)" branch$/ do |local_branch, remote_branch|
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_sha).first.id
  local_sha.should == remote_sha
end

