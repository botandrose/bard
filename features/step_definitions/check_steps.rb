Then /^I should see the current version of bard$/ do
  version = File.read("#{ROOT}/VERSION").chomp
  @stdout.should =~ /bard\s+\(#{Regexp.escape(version)}\)/
end

Then /^I should see the current version of git$/ do
  version = `git --version`[/[0-9]+\.[0-9]+\.[0-9]+/]
  @stdout.should =~ /git\s+\(#{Regexp.escape(version)}/
end

Then /^I should see the current version of rubygems$/ do
  version = `gem --version`.chomp
  @stdout.should =~ /rubygems\s+\(#{Regexp.escape(version)}\)/
end

Then /^I should see the current version of ruby$/ do
  version = `ruby --version`[/[0-9]+\.[0-9]+\.[0-9]+/]
  @stdout.should =~ /ruby\s+\(#{Regexp.escape(version)}\)/
end

Given /^"([^\"]*)" is missing$/ do |file|
  type "rm #{file}"
end

Given /^the database is missing$/ do
  File.open "config/database.yml", "w" do |f|
    f.puts <<-DB
development:
  adapter: mysql
  username: root
  password:
  database: bad_bad_bad
  socket: /var/run/mysqld/mysqld.sock
DB
  end
end

Given /^the submodule is missing$/ do
  type "rm -rf submodule"
  type "mkdir submodule"
end

Given /^the submodule has a detached head$/ do
  Dir.chdir "submodule" do
    type "git checkout `git rev-parse HEAD`"
  end
end
