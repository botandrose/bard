# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{bard}
  s.version = "0.14.2"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = [%q{Micah Geisel}, %q{Nick Hogle}]
  s.date = %q{2011-08-16}
  s.description = %q{This immaculate work of engineering genius allows mere mortals to collaborate with beings of transcendent intelligence like Micah, Michael, and Nick.}
  s.email = %q{info@botandrose.com}
  s.executables = [%q{bard}]
  s.extra_rdoc_files = [
    "LICENSE",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".gitmodules",
    ".rvmrc",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "bard.gemspec",
    "bin/bard",
    "features/bard_check.feature",
    "features/bard_deploy.feature",
    "features/bard_pull.feature",
    "features/bard_push.feature",
    "features/step_definitions/check_steps.rb",
    "features/step_definitions/git_steps.rb",
    "features/step_definitions/global_steps.rb",
    "features/step_definitions/rails_steps.rb",
    "features/step_definitions/submodule_steps.rb",
    "features/support/env.rb",
    "features/support/grit_ext.rb",
    "features/support/io.rb",
    "lib/bard.rb",
    "lib/bard/capistrano.rb",
    "lib/bard/check.rb",
    "lib/bard/error.rb",
    "lib/bard/git.rb",
    "lib/bard/io.rb",
    "lib/bard/ssh_delegation.rb",
    "lib/bard/template.rb",
    "lib/bard/template/adva.rb",
    "lib/bard/template/authlogic.rb",
    "lib/bard/template/compass.rb",
    "lib/bard/template/exception_notifier.rb",
    "lib/bard/template/gems.rb",
    "lib/bard/template/helper.rb",
    "lib/bard/template/initial.rb",
    "lib/bard/template/static_pages.rb",
    "lib/bard/template/testing.rb",
    "spec/bard_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = %q{http://github.com/botandrose/bard}
  s.require_paths = [%q{lib}]
  s.rubygems_version = %q{1.8.5}
  s.summary = %q{Tools for collaborating with Bot and Rose Design.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<ruby-debug>, [">= 0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<cucumber>, [">= 0"])
      s.add_runtime_dependency(%q<thor>, ["= 0.11.7"])
      s.add_runtime_dependency(%q<capistrano>, ["= 2.5.10"])
      s.add_runtime_dependency(%q<grit>, ["= 1.1.1"])
      s.add_runtime_dependency(%q<git_remote_branch>, [">= 0.3.0"])
      s.add_runtime_dependency(%q<versionomy>, [">= 0.3.0"])
      s.add_runtime_dependency(%q<systemu>, [">= 1.2.0"])
      s.add_runtime_dependency(%q<term-ansicolor>, [">= 1.0.3"])
      s.add_runtime_dependency(%q<bard-rake>, [">= 0.1.1"])
    else
      s.add_dependency(%q<ruby-debug>, [">= 0"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<cucumber>, [">= 0"])
      s.add_dependency(%q<thor>, ["= 0.11.7"])
      s.add_dependency(%q<capistrano>, ["= 2.5.10"])
      s.add_dependency(%q<grit>, ["= 1.1.1"])
      s.add_dependency(%q<git_remote_branch>, [">= 0.3.0"])
      s.add_dependency(%q<versionomy>, [">= 0.3.0"])
      s.add_dependency(%q<systemu>, [">= 1.2.0"])
      s.add_dependency(%q<term-ansicolor>, [">= 1.0.3"])
      s.add_dependency(%q<bard-rake>, [">= 0.1.1"])
    end
  else
    s.add_dependency(%q<ruby-debug>, [">= 0"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<cucumber>, [">= 0"])
    s.add_dependency(%q<thor>, ["= 0.11.7"])
    s.add_dependency(%q<capistrano>, ["= 2.5.10"])
    s.add_dependency(%q<grit>, ["= 1.1.1"])
    s.add_dependency(%q<git_remote_branch>, [">= 0.3.0"])
    s.add_dependency(%q<versionomy>, [">= 0.3.0"])
    s.add_dependency(%q<systemu>, [">= 1.2.0"])
    s.add_dependency(%q<term-ansicolor>, [">= 1.0.3"])
    s.add_dependency(%q<bard-rake>, [">= 0.1.1"])
  end
end

