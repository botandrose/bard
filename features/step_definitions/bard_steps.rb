Given /^a test server is running$/ do
  raise "Test server failed to start" unless @container && @ssh_port
end

When /^I run: bard (.+)$/ do |command|
  run_bard(command)
  unless @status.success?
    raise "Command failed with status: #{@status}\nOutput: #{@stdout}"
  end
end

When /^I run expecting failure: bard (.+)$/ do |command|
  run_bard(command)
  unless !@status.success?
    raise "Command succeeded but was expected to fail\nOutput: #{@stdout}"
  end
end

Then /^the output should contain "([^\"]+)"$/ do |expected|
  expect(@stdout).to include(expected)
end

Given /^I create a file "([^\"]+)" with content "([^\"]+)"$/ do |filename, content|
  Dir.chdir(@test_dir) do
    File.write(filename, content)
  end
end

Given /^I commit the changes with message "([^\"]+)"$/ do |message|
  Dir.chdir(@test_dir) do
    system("git add -A", out: File::NULL, err: File::NULL)
    system("git commit -m '#{message}'", out: File::NULL, err: File::NULL)
  end
end

Then /^a file "([^\"]+)" should exist locally$/ do |filename|
  path = File.join(@test_dir, filename)
  expect(File.exist?(path)).to be(true), "Expected file #{filename} to exist at #{path}"
end
