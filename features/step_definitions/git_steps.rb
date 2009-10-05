Given /^I am on a non\-integration branch$/ do
  type "git checkout -b bad_bad_bad"
end

Given /^I am on the master branch$/ do
  type "git checkout master"
end

Given /^there is no integration branch$/ do
  type "git checkout master"
  type "git branch -d integration"
end

Given /^there is no integration branch on the staging server$/ do
  type "git branch -d origin/integration"
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout master"
    type "git branch -d integration"
  end
end

Given /^a dirty working directory$/ do
  File.open("dirty_file", "w") { |f| f.puts "dirty dirty" }
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

Then /^the directory should not be dirty$/ do
  type("git status").should include "working directory clean"
end

Then /^the remote directory should not be dirty$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type("git status").should include "working directory clean"
  end
end

Then /^I should be on the "([^\"]*)" branch$/ do |branch|
  @repo.head.name.should == branch
end

Then /^there should not be a "([^\"]*)" branch$/ do |branch_name|
  @repo.branches.any? { |branch| branch.name == branch_name }
end

Then /^the "([^\"]*)" branch (should|should not) match the "([^\"]*)" branch$/ do |local_branch, which, remote_branch|
  type "git fetch origin"
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_branch).first.id
  which = which.gsub(/ /, '_').to_sym
  local_sha.send(which) == remote_sha
end

Then /^the "([^\"]*)" branch should be a fast\-forward from the "([^\"]*)" branch$/ do |local_branch, remote_branch|
  local_sha = @repo.commits(local_branch).first.id
  remote_sha = @repo.commits(remote_branch).first.id
  common_ancestor = @repo.find_common_ancestor local_sha, remote_sha
  common_ancestor.should  == remote_sha
end
