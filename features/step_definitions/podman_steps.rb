Given /^a podman testcontainer is ready for bard$/ do
  raise "Podman testcontainer failed to start" unless @podman_container && @podman_ssh_port
end

Given /^a remote file "([^\"]+)" exists in the test container$/ do |filename|
  run_ssh("touch testproject/#{filename}").should be_true
end

Given /^a remote file "([^\"]+)" containing "([^\"]+)" exists in the test container$/ do |filename, content|
  run_ssh("echo #{Shellwords.escape(content)} > testproject/#{filename}").should be_true
end

When /^I run bard "([^\"]+)" against the test container$/ do |command|
  run_bard_against_container(command)
end

Then /^the bard command should succeed$/ do
  @status.success?.should be_true
end

Then /^the bard output should include "([^\"]+)"$/ do |expected|
  @stdout.should include(expected)
end
