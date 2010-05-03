require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "bard"
    gem.summary = %Q{Tools for collaborating with Bot and Rose Design.}
    gem.description = %Q{This immaculate work of engineering genius allows mere mortals to collaborate with beings of transcendent intelligence like Micah, Michael, and Nick.}
    gem.email = "info@botandrose.com"
    gem.homepage = "http://github.com/botandrose/bard"
    gem.authors = ["Micah Geisel", "Nick Hogle"]
    gem.add_development_dependency "ruby-debug"
    gem.add_development_dependency "rspec"
    gem.add_development_dependency "cucumber"
    gem.add_dependency(%q<thor>, ["= 0.11.7"])
    gem.add_dependency(%q<capistrano>, ["= 2.5.10"])
    gem.add_dependency(%q<grit>, ["= 1.1.1"])
    gem.add_dependency(%q<git_remote_branch>, [">= 0.3.0"])
    gem.add_dependency(%q<versionomy>, [">= 0.3.0"])
    gem.add_dependency(%q<systemu>, [">= 1.2.0"])
    gem.add_dependency(%q<term-ansicolor>, [">= 1.0.3"])
    gem.add_dependency(%q<bard-rake>, [">= 0.1.0"])
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: sudo gem install jeweler"
end

task :release do
  system "git push"
  system "git push github"
  Rake::Task["gemcutter:release"].invoke
end

require 'spec/rake/spectask'
Spec::Rake::SpecTask.new(:spec) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.spec_files = FileList['spec/**/*_spec.rb']
end

Spec::Rake::SpecTask.new(:rcov) do |spec|
  spec.libs << 'lib' << 'spec'
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rcov = true
end

task :spec => :check_dependencies

begin
  require 'cucumber/rake/task'
  Cucumber::Rake::Task.new(:features)

  task :features => :check_dependencies
rescue LoadError
  task :features do
    abort "Cucumber is not available. In order to run features, you must: sudo gem install cucumber"
  end
end

begin
  require 'reek/rake_task'
  Reek::RakeTask.new do |t|
    t.fail_on_error = true
    t.verbose = false
    t.source_files = 'lib/**/*.rb'
  end
rescue LoadError
  task :reek do
    abort "Reek is not available. In order to run reek, you must: sudo gem install reek"
  end
end

begin
  require 'roodi'
  require 'roodi_task'
  RoodiTask.new do |t|
    t.verbose = false
  end
rescue LoadError
  task :roodi do
    abort "Roodi is not available. In order to run roodi, you must: sudo gem install roodi"
  end
end

task :default => :spec

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  if File.exist?('VERSION')
    version = File.read('VERSION')
  else
    version = ""
  end

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "bard #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
