Given /^a podman testcontainer is ready for bard$/ do
  raise "Podman testcontainer failed to start" unless @podman_container && @podman_ssh_port
end

Given /^a remote file "([^\"]+)" exists in the test container$/ do |filename|
  result = run_ssh("touch testproject/#{filename}")
  expect(result).to be true
end

Given /^a remote file "([^\"]+)" containing "([^\"]+)" exists in the test container$/ do |filename, content|
  result = run_ssh("echo #{Shellwords.escape(content)} > testproject/#{filename}")
  expect(result).to be true
end

When /^I run bard "([^\"]+)" against the test container$/ do |command|
  run_bard_against_container(command)
end

Then /^the bard command should succeed$/ do
  unless @status.success?
    puts "BARD COMMAND FAILED"
    puts "Status: #{@status}"
    puts "Output: #{@stdout}"
  end
  expect(@status.success?).to be true
end

Then /^the bard command should fail$/ do
  expect(@status.success?).to be false
end

Then /^the bard output should include "([^\"]+)"$/ do |expected|
  expect(@stdout).to include(expected)
end
