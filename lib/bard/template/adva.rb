load_template "../bard_template/helper.rb"

# Download and install Adva CMS
file "script/test-adva-cms", <<-src
  #!/usr/bin/env ruby
  paths = ARGV.clone
  load 'vendor/adva/script/test'
src
 
file_inject 'config/environment.rb',
  "require File.join(File.dirname(__FILE__), 'boot')",
  "require File.join(File.dirname(__FILE__), '../vendor/adva/engines/adva_cms/boot')"
 
git :submodule => "add -b bard git@git.botandrose.com:adva.git vendor/adva # this might take a bit, grab a coffee meanwhile :)"
git :submodule => "update --init"
inside("vendor/adva") do
  run "git remote add github git://github.com/svenfuchs/adva_cms.git"
  run "git checkout -b #{project_name}/integration"
end
 
rake "adva:install:core -R vendor/adva/engines/adva_cms/lib/tasks"
rake "adva:assets:install"

# Install FCKEditor plugin
rake "adva:install plugins=adva_fckeditor"
file "config/initializers/fckeditor.rb", <<-src
Fckeditor.load!
src
run "cp public/javascripts/adva_fckeditor/config.js public/javascripts/fck_config.js"
file_append "public/javascripts/fck_config.js", <<-src
FCKConfig.CustomStyles = {};
FCKConfig.StylesXmlPath = '/stylesheets/fck_styles.xml';

FCKConfig.EditorAreaCSS = '/stylesheets/fck_editor.css';
FCKConfig.BodyClass = '';

FCKConfig.FirefoxSpellChecker = true;
FCKConfig.BrowserContextMenuOnCtrl = true;
FCKConfig.ForcePasteAsPlainText = true;
src
run "cp public/javascripts/adva_fckeditor/fckeditor/fckstyles.xml public/stylesheets/fck_styles.xml"
file "public/stylesheets/fck_editor.css"

# Setup FCKEditor upload connector
run "mkdir public/userfiles"
run "chmod 777 public/userfiles"
file "public/userfiles/.gitignore", ""
file_append ".gitignore", <<-src
public/userfiles/*
!public/userfiles/.gitignore
src

git :add => "."
git :commit => "-m'added adva cms.'"
