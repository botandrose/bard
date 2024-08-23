module Bard::CLI::Install
  def self.included mod
    mod.class_eval do

      desc "install", "copies bin/setup and bin/ci scripts into current project."
      def install
        install_files_path = File.expand_path(File.join(__dir__, "../../install_files/*"))
        system "cp -R #{install_files_path} bin/"
        github_files_path = File.expand_path(File.join(__dir__, "../../install_files/.github"))
        system "cp -R #{github_files_path} ./"
      end

    end
  end
end

