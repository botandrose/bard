Given /^a shared test project$/ do
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

Given /^I have committed a set of changes to my local integration branch$/ do
  type "echo 'fuck shit' > fuck_file"
  type "git add ."
  type "git commit -am'test commit to local integration branch.'"
end

Given /^the remote integration branch has had a commit since I last pulled$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    type "echo 'zomg' > origin_change_file"
    type "git add ."
    type "git commit -am 'testing origin change'"
  end
end

Given /^a dirty working directory$/ do
  File.open("dirty_file", "w") { |f| f.puts "dirty dirty" }
end

When /^I type "([^\"]*)"$/ do |command|
  type command
end

Then /^I should be on the "([^\"]*)" branch$/ do |branch|
  @repo.head.name.should == branch
end

Then /^the "([^\"]*)" branch (should|should not) match the "([^\"]*)" branch$/ do |local_branch, which, remote_branch|
  type "git fetch origin"
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_branch).first.id
  which = which.gsub(/ /, '_').to_sym
  local_sha.send(which) == remote_sha
end

Then /^I should see the fatal error "([^\"]*)"$/ do |error_message|
  @stderr.should include(error_message)
end

Then /^I should see the warning "([^\"]*)"$/ do |warning_message|
  @stderr.should include(warning_message) 
end

Then /^the "([^\"]*)" branch should be a fast\-forward from the "([^\"]*)" branch$/ do |local_branch, remote_branch|
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_branch).first.id
  common_ancestor = find_common_ancestor local_sha, remote_sha
  common_ancestor.should  == remote_sha
end

def find_common_ancestor(head1, head2)
  `git merge-base #{head1} #{head2}`.chomp
end

Then /^there should not be a "([^\"]*)" branch$/ do |branch_name|
  @repo.branches.any? { |branch| branch.name == branch_name }
end

