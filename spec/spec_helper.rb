require "simplecov"
SimpleCov.start do
  command_name "RSpec"
  track_files "lib/**/*.rb"
  add_filter "spec/"
  add_filter "features/"
end

require "webmock/rspec"

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require "debug/prelude"

RSpec.configure do |config|
  config.filter_run focus: true
  config.run_all_when_everything_filtered = true
end

