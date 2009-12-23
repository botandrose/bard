$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'ruby-debug'
require 'grit'
require 'spec/expectations'
require 'systemu'
gem 'sqlite3-ruby'

ENV["PATH"] += ":#{File.dirname(File.expand_path(__FILE__))}/../../bin"
ENV["GIT_DIR"] = nil
ENV["GIT_WORK_TREE"] = nil
ENV["GIT_INDEX_FILE"] = nil

ROOT = File.expand_path(File.dirname(__FILE__) + '/../..')

# setup fixtures
FileUtils.rm_rf "tmp"
FileUtils.mkdir "tmp"
FileUtils.cp_r "fixtures/repo", "tmp/origin"
Dir.chdir 'tmp/origin' do
  `git config receive.denyCurrentBranch ignore`
  File.open ".git/hooks/post-receive", "w" do |f|
    f.puts <<-BASH
#!/bin/bash
RAILS_ENV=staging #{ROOT}/bin/bard stage $@
BASH
    f.chmod 0775
  end
  FileUtils.cp "config/database.sample.yml", "config/database.yml"
  `git checkout -b integration`
end
FileUtils.cp_r "fixtures/repo", "tmp/submodule"
FileUtils.cp_r "fixtures/repo", "tmp/submodule2"
`git clone tmp/origin tmp/local`
Dir.chdir 'tmp/local' do
  `grb fetch integration && git checkout integration`
  FileUtils.cp "config/database.sample.yml", "config/database.yml"
end
FileUtils.mkdir "tmp/fixtures"
Dir.foreach "tmp" do |file|
  FileUtils.mv("tmp/#{file}", "tmp/fixtures/") unless %w(fixtures . ..).include? file
end
