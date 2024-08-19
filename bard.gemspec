# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "bard/version"

Gem::Specification.new do |spec|
  spec.name          = "bard"
  spec.version       = Bard::VERSION
  spec.authors       = ["Micah Geisel"]
  spec.email         = ["micah@botandrose.com"]
  spec.summary       = "CLI to automate common development tasks."
  spec.homepage      = "http://github.com/botandrose/bard"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = ["bard"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "thor", ">= 0.19.0"
  spec.add_dependency "rvm"
  spec.add_dependency "term-ansicolor", ">= 1.0.3"

  spec.add_development_dependency "byebug"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "cucumber"
end
