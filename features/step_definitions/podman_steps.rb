Given /^a test server is running$/ do
  raise "Test server failed to start" unless @podman_container && @podman_ssh_port
end

When /^I run: bard (.+)$/ do |command|
  run_bard(command)
end

Then /^it should succeed$/ do
  unless @status.success?
    puts "Command failed with status: #{@status}"
    puts "Output: #{@stdout}"
  end
  expect(@status.success?).to be true
end

Then /^it should fail$/ do
  expect(@status.success?).to be false
end

Then /^the output should contain "([^\"]+)"$/ do |expected|
  expect(@stdout).to include(expected)
end
