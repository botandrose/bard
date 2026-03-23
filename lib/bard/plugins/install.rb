require "bard/plugin"

class Bard::CLI::Install < Bard::Plugin::Command
  desc "install", "copies bin/setup and bin/ci scripts into current project."
  def install
    install_files_path = File.expand_path(File.join(__dir__, "../../../install_files"))

    system "cp -R #{install_files_path}/* bin/"
    system "cp -R #{install_files_path}/.github ./"
  end
end

Bard::Plugin.register :install do
  cli Bard::CLI::Install
end
