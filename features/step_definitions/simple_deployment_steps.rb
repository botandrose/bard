Given /^a shared test project$/ do
  # TEARDOWN
  Dir.chdir ROOT
  type "rm -rf tmp"
  
  # SETUP
  Dir.chdir ROOT
  Dir.mkdir 'tmp'
  type "cp -R fixtures/test_repo_source tmp/test_repo_origin"
  type "git clone tmp/test_repo_origin tmp/test_repo_local"
  Dir.chdir 'tmp/test_repo_local'
  @repo = Grit::Repo.new "."
  @repo.remote_branches.each do |remote_branch|
    type "grb track #{remote_branch}"
  end
end

Given /^I have committed a set of changes to my local integration branch$/ do
  type "git checkout integration"
  type "cat 'fuck shit' > fuck_file"
  type "git add ."
  type "git commit -am'test commit to local integration branch.'"
end

Given /^the remote integration branch has had a commit since I last pulled$/ do
  Dir.chdir "#{ROOT}/tmp/test_repo_origin" do 
    type "git checkout integration"
    type "cat 'zomg' > origin_change_file"
    type "git add ."
    type "git commit -am 'testing origin change'"
  end
end

Given /^a dirty working directory$/ do
  File.open("new_file", "w") { |f| f.puts "blah blah blah" }
end

When /^I type "([^\"]*)"$/ do |command|
  type command
end

Then /^I should be on the "([^\"]*)" branch$/ do |branch|
  @repo.head.name.should == branch
end

Then /^the "([^\"]*)" branch (should|should not) match the "([^\"]*)" branch$/ do |local_branch, which, remote_branch|
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_branch).first.id
  which = which.gsub(/ /, '_').to_sym
  local_sha.send(which) == remote_sha
end

Then /^I should see the fatal error "([^\"]*)"$/ do |error_message|
  @stderr.should include(error_message)
end

Then /^there should not be a "([^\"]*)" branch$/ do |branch_name|
  @repo.branches.any? { |branch| branch.name == branch_name }
end
