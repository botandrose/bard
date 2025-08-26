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

# Branch management
Given /^I create and switch to branch "([^"]+)"$/ do |branch_name|
  Dir.chdir(@test_dir) do
    system("git checkout -b #{branch_name}", out: File::NULL, err: File::NULL)
  end
end

Then /^I should be on branch "([^"]+)"$/ do |expected_branch|
  Dir.chdir(@test_dir) do
    current = `git rev-parse --abbrev-ref HEAD`.chomp
    expect(current).to eq(expected_branch)
  end
end

Given /^I push branch "([^"]+)" to origin$/ do |branch_name|
  Dir.chdir(@test_dir) do
    system("git push -u origin #{branch_name}", out: File::NULL, err: File::NULL)
  end
end

Then /^branch "([^"]+)" should not exist locally$/ do |branch_name|
  Dir.chdir(@test_dir) do
    result = system("git rev-parse --verify #{branch_name}", out: File::NULL, err: File::NULL)
    expect(result).to be(false), "Expected branch #{branch_name} to not exist locally"
  end
end

Then /^branch "([^"]+)" should not exist on origin$/ do |branch_name|
  Dir.chdir(@test_dir) do
    system("git fetch --prune origin", out: File::NULL, err: File::NULL)
    result = system("git rev-parse --verify origin/#{branch_name}", out: File::NULL, err: File::NULL)
    expect(result).to be(false), "Expected branch #{branch_name} to not exist on origin"
  end
end

# Simulating remote changes
Given /^master has an additional commit from another source$/ do
  run_ssh "cd ~/testproject && git pull origin master"
  run_ssh "cd ~/testproject && echo 'remote change' > remote-change.txt"
  run_ssh "cd ~/testproject && git add remote-change.txt"
  run_ssh "cd ~/testproject && git commit -m 'Remote commit on master'"
  run_ssh "cd ~/testproject && git push origin master"

  Dir.chdir(@test_dir) do
    system("git fetch origin", out: File::NULL, err: File::NULL)
  end
end

Given /^master has a conflicting commit to "([^"]+)"$/ do |filename|
  run_ssh "cd ~/testproject && git pull origin master"
  run_ssh "cd ~/testproject && echo 'conflicting content from remote' > #{filename}"
  run_ssh "cd ~/testproject && git add #{filename}"
  run_ssh "cd ~/testproject && git commit -m 'Remote conflicting commit'"
  run_ssh "cd ~/testproject && git push origin master"

  Dir.chdir(@test_dir) do
    system("git fetch origin", out: File::NULL, err: File::NULL)
  end
end

# CI setup
Given /^a local CI script that passes$/ do
  Dir.chdir(@test_dir) do
    File.write("bin/rake", <<~'SCRIPT')
#!/bin/bash
case "$1" in
  ci) echo "All tests passed!"; exit 0 ;;
esac
    SCRIPT
    FileUtils.chmod(0o755, "bin/rake")
  end
end

Given /^a local CI script that fails with "([^"]+)"$/ do |error_message|
  Dir.chdir(@test_dir) do
    File.write("bin/rake", <<~SCRIPT)
#!/bin/bash
case "$1" in
  ci) echo "#{error_message}"; exit 1 ;;
esac
    SCRIPT
    FileUtils.chmod(0o755, "bin/rake")
  end
end

Given /^I switch to branch "([^"]+)"$/ do |branch_name|
  Dir.chdir(@test_dir) do
    system("git checkout #{branch_name}", out: File::NULL, err: File::NULL)
  end
end

# Output negation
Then /^the output should not contain "([^"]+)"$/ do |unexpected|
  expect(@stdout).not_to include(unexpected)
end
