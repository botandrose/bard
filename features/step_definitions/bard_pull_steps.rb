Given /^the remote integration branch has had a commit that includes a new submodule$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    type "git submodule add #{ROOT}/tmp/submodule submodule"
    type "git add ."
    type "git commit -am 'added submodule'"
  end
end

Given /^the remote integration branch has had a commit that includes a submodule update$/ do
  Dir.chdir "#{ROOT}/tmp/submodule" do 
    type "git checkout master"
    type "echo 'zomg' > submodule_change_file"
    type "git add ."
    type "git commit -am 'the remote integration branch now has a modified submodule'"
  end
  Dir.chdir "#{ROOT}/tmp/origin/submodule" do 
    type "git pull"
  end
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git commit -am 'remote integration branch now has a commit that includes a submodule update'"
  end
end

Given /^the remote integration branch has had a commit that includes a submodule url change$/ do
  pending
end

Given /^the remote integration branch has had a commit that includes a submodule deletion$/ do
  pending
end

Then /^there should be one new submodule$/ do
  File.read(".gitmodules").scan( '[submodule "submodule"]' ).should have(1).things
end

Then /^the submodule should be checked out$/ do
  `git submodule status`.should match /^ [0-9a-f]/
end

Then /^the submodule should be updated$/ do
  `git submodule status`.should match /^ [0-9a-f]/
  pending
end

Then /^the submodule url should be changed$/ do
  pending
end

Then /^the submodule should be deleted$/ do
  pending
end

Then /^there should be one submodule that is checked out$/ do
  pending
end

