Given /^the remote integration branch has had a commit that includes a new submodule$/ do
  Dir.chdir "#{ROOT}/tmp/origin" do 
    type "git checkout integration"
    type "git submodule add #{ROOT}/tmp/submodule submodule"
    type "git add ."
    type "git commit -am 'added submodule'"
  end
end

Given /^the remote integration branch has had a commit that includes a submodule update$/ do
  pending
end

Given /^the remote integration branch has had a commit that includes a submodule url change$/ do
  pending
end

Given /^the remote integration branch has had a commit that includes a submodule deletion$/ do
  pending
end

Then /^there should be one new submodule$/ do
  File.read(".gitmodules").should.include '[submodule "submodule"]'
end

Then /^the submodule should be checked out$/ do
  pending
end

Then /^the submodule should be updated$/ do
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

