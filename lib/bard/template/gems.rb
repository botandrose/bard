# Install .rvmrc
run "rvm use ree-1.8.7-2010.02@#{project_name} --rvmrc --create"
begin
  require "rvm"
  RVM.gemset_use! project_name
rescue LoadError
end

# Install bundler files
file "Gemfile", <<-END
source "http://gemcutter.org"

gem "rails", "2.3.5"
gem "ruby-mysql"
gem "bard-rake", :require => false
gem "ruby-debug", :group => [:development, :test, :cucumber]

gem "haml", "~>3.0"
gem "compass", "~>0.10"

group :test, :cucumber do
  gem "autotest-rails"
  gem "rspec-rails", "~>1.3", :require => false
  gem "machinist"
  gem "faker"
end

group :cucumber do
  gem "cucumber-rails", :require => false
  gem "webrat"
  gem "database_cleaner"
  gem "pickle"
  gem "email_spec"
end
END
run "bundle install --relock"

file_inject "config/boot.rb", 
"# All that for this:", <<-END, :before
class Rails::Boot
  def run
    load_initializer

    Rails::Initializer.class_eval do
      def load_gems
        @bundler_loaded ||= Bundler.require :default, Rails.env
      end
    end

    Rails::Initializer.run(:set_load_path)
  end
end

END

file "config/preinitializer.rb", <<-END
begin
  require "rubygems"
  require "bundler"
rescue LoadError
  raise "Could not load the bundler gem. Install it with `gem install bundler`."
end

if Gem::Version.new(Bundler::VERSION) <= Gem::Version.new("0.9.24")
  raise RuntimeError, "Your bundler version is too old." +
    "Run `gem install bundler` to upgrade."
end

begin
  # Install dependencies if needed
  `bundle check`
  system "bundle install" if not $?.success?
  # Set up load paths for all bundled gems
  ENV["BUNDLE_GEMFILE"] = File.expand_path("../../Gemfile", __FILE__)
  Bundler.setup
rescue Bundler::GemNotFound
  raise RuntimeError, "Bundler couldn't find some gems." +
    "Did you run `bundle install`?"
end
END

file "config/setup_load_paths.rb", ""

