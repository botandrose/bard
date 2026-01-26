require "bard/cli/command"

class Bard::CLI::Install < Bard::CLI::Command
  desc "install", "copies bin/setup and bin/ci scripts into current project."
  def install
    install_files_path = File.expand_path(File.join(__dir__, "../../../install_files"))

    system "cp -R #{install_files_path}/* bin/"
    system "cp -R #{install_files_path}/.github ./"
  end
end
