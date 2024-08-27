module Bard::CLI::Install
  def self.included mod
    mod.class_eval do

      desc "install", "copies bin/setup and bin/ci scripts into current project."
      def install
        install_files_path = File.expand_path(File.join(__dir__, "../../../install_files"))

        system "cp -R #{install_files_path}/* bin/"
        system "cp -R #{install_files_path}/.github ./"
      end

    end
  end
end

