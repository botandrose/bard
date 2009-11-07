# this file installs the dotfiles into your system automatically on gem install by spoofing as a C extension. naughty!

# trick rubygems into thinking we're actually building an extension
File.open('Makefile', 'w') { |f| f.write "all:\n\ninstall:\n\n" }

require 'ftools'
require 'fileutils'

ROOT = File.expand_path(File.join(File.dirname(__FILE__), '..', '..'))

# copy dotfiles to ~/.bard
dotfile_path = File.expand_path('~/.bard')
FileUtils.rm_r(dotfile_path) if File.directory?(dotfile_path)
FileUtils.cp_r "#{ROOT}/dotfiles", dotfile_path

# install into .bashrc
bashrc_path = File.expand_path('~/.bashrc')
File.open bashrc_path, "a+" do |f|
  unless f.read.include? "~/.bard/bashrc"
    f << "
# include bashrc from bard gem
if [ -f ~/.bard/bashrc ]; then
  . ~/.bard/bashrc
fi
"
  end
end

