Given /^I am on the "([^\"]+)" branch$/ do |branch|
  if `git branch` =~ / #{branch}$/
    type "git checkout #{branch}"
  else
    type "git checkout -b #{branch}"
  end
end

Given /^there is no integration branch$/ do
  type "git checkout master"
  type "git branch -d integration"
end

Given /^the integration branch isnt tracking origin\/integration$/ do
  type "git checkout master"
  type "git branch -d integration"
  type "git checkout -b integration"
end

Given /^a dirty working directory$/ do
  File.open("dirty_file", "w") { |f| f.puts "dirty dirty" }
end

Given /^a commit$/ do
  text = (rand * 100000000).round
  type "echo '#{text}' > foobar_#{text}_file"
  type "git add ."
  type "git commit -am'test commit'"
end

Given /^a commit on the "([^\"]+)" branch$/ do |branch|
  Given %(I am on the "#{branch}" branch)
  text = (rand * 100000000).round
  type "echo '#{text}' > #{branch}_#{text}_file"
  type "git add ."
  type "git commit -am 'testing #{branch} change'"
  type "git checkout integration"
end

Then /^the directory should not be dirty$/ do
  type("git status").should include "working directory clean"
end

Then /^I should be on the "([^\"]*)" branch$/ do |branch|
  @repo.head.name.should == branch
end

Then /^there should not be a "([^\"]*)" branch$/ do |branch_name|
  @repo.branches.any? { |branch| branch.name == branch_name }
end

Then /^the "([^\"]*)" branch (should|should not) match the "([^\"]*)" branch$/ do |local_branch, which, remote_branch|
  type "git fetch origin"
  local_env, local_branch = local_branch.split(':') if local_branch.include? ':'
  local_env ||= "development_a"
  remote_env, remote_branch = remote_branch.split(':') if remote_branch.include? ':'
  remote_env ||= "development_a"
  local_sha = @repos[local_env].commits(local_branch).first.id
  remote_sha = @repos[remote_env].commits(remote_branch).first.id
  which = which.gsub(/ /, '_').to_sym
  local_sha.send(which) == remote_sha
end

Then /^the "([^\"]*)" branch should be a fast\-forward from the "([^\"]*)" branch$/ do |local_branch, remote_branch|
  local_env, local_branch = local_branch.split(':') if local_branch.include? ':'
  local_env ||= "development_a"
  remote_env, remote_branch = remote_branch.split(':') if remote_branch.include? ':'
  remote_env ||= "development_a"
  local_sha = @repos[local_env].commits(local_branch).first.id
  remote_sha = @repos[remote_env].commits(remote_branch).first.id
  common_ancestor = @repos[local_env].find_common_ancestor local_sha, remote_sha
  common_ancestor.should  == remote_sha
end
