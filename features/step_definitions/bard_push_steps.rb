Given /^a submodule$/ do
  Given 'the remote integration branch has had a commit that includes a new submodule'
  Dir.chdir "#{ROOT}/tmp/local" do
    type "git checkout integration"
    type "git pull --rebase"
    type "git submodule update --init"
  end
end

Given /^the submodule working directory is dirty$/ do
  Dir.chdir "#{ROOT}/tmp/local/submodule" do
    type "git checkout master"
    type "echo 'submodule_update' > submodule_update"
  end
end

Given /^I have committed a set of changes to the submodule$/ do
  Dir.chdir "#{ROOT}/tmp/local/submodule" do
    type "git checkout -b master"
    type "echo 'submodule_update' > submodule_update"
    type "git add ."
    type "git commit -am 'update in submodule'"
  end
end

