# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.authors       = ["Micah Geisel", "Nick Hogle"]
  gem.email         = ["micah@botandrose.com"]
  gem.description   = %q{This immaculate work of engineering genius allows mere mortals to collaborate with beings of transcendent intelligence like Micah, Michael, and Nick.}
  gem.summary       = %q{Tools for collaborating with Bot and Rose Design.}
  gem.homepage      = "https://github.com/botandrose/bard"

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "bard"
  gem.require_paths = ["lib"]
  gem.version       = File.read("VERSION").chomp

  gem.add_dependency "thor", "0.11.7"
  gem.add_dependency "capistrano", "2.5.10"
  gem.add_dependency "rvm-capistrano"
  gem.add_dependency "grit", "1.1.1"
  gem.add_dependency "git_remote_branch", ">=0.3.0"
  gem.add_dependency "versionomy", ">=0.3.0"
  gem.add_dependency "systemu", ">=1.2.0"
  gem.add_dependency "term-ansicolor", ">=1.0.3"
  gem.add_dependency "bard-rake", ">=0.1.1"

  gem.add_development_dependency "rspec", "~>1.3.0"
  gem.add_development_dependency "cucumber", "~>0.9.0"
end
