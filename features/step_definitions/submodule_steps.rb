Given /^a submodule$/ do
  Given 'on development_b, a commit with a new submodule'
  Given 'on development_b, I type "bard push"'
  Given 'I type "bard pull"'
  @submodule_url = File.read(".gitmodules").match(/url = (.*)$/)[1]
  @submodule_commit = type "git submodule status"
end

Given /^the submodule working directory is dirty$/ do
  Dir.chdir "submodule" do
    type "git checkout master"
    type "echo 'submodule_update' > submodule_update"
  end
end

Given /^a commit to the submodule$/ do
  Dir.chdir "submodule" do
    type "echo 'submodule_update' > submodule_update"
    type "git add ."
    type "git commit -am 'update in submodule'"
  end
end

Given /^a commit with a new submodule$/ do
  type "git submodule add #{ROOT}/tmp/submodule_a.git submodule"
  type "git submodule init"
  type "git submodule update --merge"
  Dir.chdir "submodule" do
    type "git checkout -b master origin/master"
  end
  type "git add ."
  type "git commit -m 'added submodule'"
end

Given /^a commit with a submodule update$/ do
  type "git checkout integration"
  Dir.chdir "submodule" do
    type "git checkout master"
    type "echo 'submodule_update' > submodule_update"
    type "git add ."
    type "git commit -m 'update in submodule'"
    type "git push origin HEAD"
  end
  type "git add ."
  type "git commit -m 'updated submodule'"
end

Given /^a commit with a submodule url change$/ do
  gsub_file ".gitmodules", "submodule_a.git", "submodule_b.git"
  type "git add ."
  type "git commit -m 'updated submodule url'"
end

Given /^I a commit a with a submodule deletion$/ do
  type "rm .gitmodules"
  type "rm -rf --cached submodule"
  type "git add ."
  type "git commit -am'removed submodule'"
end

Then /^there should be one new submodule$/ do
  status = type "git submodule status"
  status.should match /.[a-z0-9]{40} submodule/
end

Then /^the submodule branch should match the submodule origin branch$/ do
  @submodule_url = File.read(".gitmodules").match(/url = (.*)$/)[1]
  @submodule_commit = type "git submodule status"
  @submodule_commit.should match %r( [a-z0-9]{40} submodule)
  Dir.chdir "submodule" do
    @submodule = Grit::Repo.new "."
    branch = @submodule.head.name rescue nil
    remote_branch = @submodule.remotes.find {|n| n.name == "origin/HEAD" }.commit.id[/\w+$/]
    branch.should_not be_nil
    remote_branch.should_not be_nil
    branch.should == remote_branch
    type("git rev-parse HEAD").should == type("git rev-parse origin/HEAD")
    type("git name-rev --name-only HEAD").should == type("git name-rev --name-only origin/HEAD")
  end
end

Then /^the submodule should be checked out$/ do
  @submodule_url = File.read(".gitmodules").match(/url = (.*)$/)[1]
  @submodule_commit = type "git submodule status"
  @submodule_commit.should match %r( [a-z0-9]{40} submodule)
end

Then /^the submodule should be updated$/ do
  @submodule_commit[/[a-z0-9]{40}/].should_not == type("git submodule status")[/[a-z0-9]{40}/]
end

Then /^the submodule url should be changed$/ do
  Dir.chdir "submodule" do
    remote = type "git remote show origin"
    remote.should_not match %r(Fetch URL: #{@submodule_url}$)
    remote.should_not match %r(Push  URL: #{@submodule_url}$)
  end
end

Then /^the submodule should be deleted$/ do
  Then 'the directory should not be dirty'
  @submodule_commit = type "git submodule status"
  @submodule_commit.should_not match /.[a-z0-9]{40} submodule/

end

Then /^the submodule working directory should be clean$/ do
  Dir.chdir "submodule" do
    type("git status").should include "working directory clean"
  end
end
