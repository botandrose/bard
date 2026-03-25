class Bard::CLI
  desc "install", "copies bin/setup and bin/ci scripts into current project."
  def install
    install_files_path = File.expand_path("install", __dir__)

    system "cp -R #{install_files_path}/* bin/"
    system "cp -R #{install_files_path}/.github ./"
  end
end
