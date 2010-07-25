# delete unnecessary files
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"
run "rm -f public/javascripts/*"
run "rm -rf test"
run "rm -rf doc"

# Install plugins
plugin "limerick_rake", :git => "git://github.com/botandrose/limerick_rake.git"
plugin "acts_as_list", :git => "git://github.com/rails/acts_as_list.git"
plugin 'asset_packager', :git => 'git://github.com/sbecker/asset_packager.git'
#plugin 'fckeditor', :git => 'git://github.com/originofstorms/fckeditor.git'
 
# Set up databases
file "config/database.sample.yml", <<-END
login: &login
  adapter: mysql
  database: #{project_name}
  username: root
  password:
  socket: /var/run/mysqld/mysqld.sock

development:
  <<: *login

test:
  <<: *login
  database: #{project_name}_test

staging:
  <<: *login

production:
  <<: *login
END
run "cp config/database.sample.yml config/database.yml"

rake "db:create"
rake "db:migrate"

# Staging Environment
run "cp config/environments/development.rb config/environments/staging.rb"

# application.html.haml
file "app/views/layouts/application.html.haml", <<-END
!!!
%html{html_attrs('en-US')}
  %head
    %meta(http-equiv="Content-Type" content="text/html; charset=utf-8")
    %title
      #{project_name}
      = yield :title
    %meta(name="keywords" content="")
    %meta(name="description" content="")

    = stylesheet_link_merged :base
    = yield :css
    /[if lte IE 7]
      = stylesheet_link_merged :ie
      
    %link(rel="shortcut icon" href="\#{image_path("/favicon.png")}" type="image/png")

  %body
    #container
      = yield
    - if flash[:notice]
      #flash_notice= flash[:notice]
    - if flash[:error]
      #flash_error= flash[:error]

    = javascript_include_tag "http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"
    = javascript_include_merged :base
    = yield :js
END

file "public/javascripts/application.js", <<-END
$(function() {
});
END

file "config/asset_packages.yml", <<-END
--- 
javascripts: 
- base:
  - application
stylesheets: 
- base: 
  - screen
  - application
- ie:
  - ie
END

plugin "input_css", :git => "git://github.com/rpheath/input_css.git"

# Set up git repository
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
file '.gitignore', <<-END
.bundle
log/*.log
tmp/*
!tmp/.gitignore
.DS_Store
public/cache/**/*
doc/api
doc/app
doc/spec/*
db/data.*
db/*.sqlite3
config/database.yml
converage/**/*
public/stylesheets/*.css
*[~]
END

# Deployment and staging setup
file_append "Rakefile", <<-END

require 'bard/rake'
END

file "Capfile", <<-END
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }
require 'bard/capistrano'
load 'config/deploy'
END

file "config/deploy.rb", <<-END
set :application, "#{project_name}"
END

git :init
git :add => "."
git :commit => "-m'initial commit.'"
git :checkout => "-b integration"

git :remote => "add origin git@git.botandrose.com:#{project_name}.git"
# run "cap staging:bootstrap"
