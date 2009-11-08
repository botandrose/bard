$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../../lib')
require 'ruby-debug'
require 'grit'
require 'spec/expectations'
require 'systemu'
gem 'sqlite3-ruby'

ENV["PATH"] += ":#{File.dirname(File.expand_path(__FILE__))}/../../bin"

ROOT = File.expand_path(File.dirname(__FILE__) + '/../..')
