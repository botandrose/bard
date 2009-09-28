Given /^the remote integration branch has had a commit that includes a new submodule$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    type "git submodule add -b master #{ROOT}/tmp/submodule submodule"
    type "git add ."
    type "git commit -m 'added submodule'"
  end
end

Given /^the remote integration branch has had a commit that includes a submodule update$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    Dir.chdir "#{ROOT}/tmp/origin/submodule" do
      type "git checkout master"
      type "echo 'submodule_update' > submodule_update"
      type "git add ."
      type "git commit -m 'update in submodule'"
      type "git push origin HEAD"
    end
    type "git add ."
    type "git commit -m 'updated submodule'"
  end
end

Given /^the remote integration branch has had a commit that includes a submodule url change$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    File.open ".gitmodules", "r+" do |f|
      gitmodules = f.read
      f.rewind
      f.puts gitmodules.gsub /url = (.*)submodule$/, "url = $1submodule2"
    end
    type "git add ."
    type "git commit -m 'updated submodule url'"
  end
end

Given /^the remote integration branch has had a commit that includes a submodule deletion$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    type "rm .gitmodules"
    type "rm -rf submodule"
    type "git add ."
    type "git commit -am'removed submodule'"
  end
end

Then /^there should be one new submodule$/ do
  status = type "git submodule status"
  status.should match /.[a-z0-9]{40} submodule/
end

Then /^the submodule should be checked out$/ do
  @submodule_commit = type "git submodule status"
  @submodule_commit.should match /.[a-z0-9]{40} submodule/
  @submodule_url = File.read(".gitmodules")[/url = .*$/]
end

Then /^the submodule should be updated$/ do
  @submodule_commit[/[a-z0-9]{40}/].should_not == type("git submodule status")[/[a-z0-9]{40}/]
end

Then /^the submodule url should be changed$/ do
  @submodule_url.should_not == File.read(".gitmodules")[/url = .*$/]
end

Then /^the submodule should be deleted$/ do
  @submodule_commit = type "git submodule status"
  @submodule_commit.should_not match /.[a-z0-9]{40} submodule/
end
