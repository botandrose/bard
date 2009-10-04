Then /^I should see the current version of bard$/ do
  version = File.read("#{ROOT}/VERSION").chomp
  @stdout.should =~ /bard\s+\(#{Regexp.escape(version)}\)/
end

Then /^I should see the current version of git$/ do
  version = `git --version`[/[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/]
  @stdout.should =~ /git\s+\(#{Regexp.escape(version)}\)/
end

Then /^I should see the current version of rubygems$/ do
  version = `gem --version`.chomp
  @stdout.should =~ /rubygems\s+\(#{Regexp.escape(version)}\)/
end

Then /^I should see the current version of ruby$/ do
  version = `ruby --version`[/[0-9]+\.[0-9]+\.[0-9]+/]
  @stdout.should =~ /ruby\s+\(#{Regexp.escape(version)}\)/
end

