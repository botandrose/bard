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
Dir.chdir 'tmp' do
  `git clone --mirror --recursive ../fixtures/repo origin.git`

  `git clone --bare --recursive origin.git submodule_a.git`
  `git clone --bare --recursive origin.git submodule_b.git`
  %w(development_a development_b staging production).each do |env|
    `git clone --recursive origin.git #{env}`
    Dir.chdir env do
      FileUtils.cp "config/database.sample.yml", "config/database.yml"
      `git checkout -b integration origin/integration` unless env == "production"
    end
  end
  FileUtils.mkdir "fixtures"
  Dir.foreach "." do |file|
    FileUtils.mv(file, "fixtures/") unless %w(fixtures . ..).include? file
  end
end
