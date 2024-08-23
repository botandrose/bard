module Bard::CLI::Hurt
  def self.included mod
    mod.class_eval do

      desc "hurt <command>", "reruns a command until it fails"
      def hurt *args
        (1..).each do |count|
          puts "Running attempt #{count}"
          system *args
          unless $?.success?
            puts "Ran #{count-1} times before failing"
            break
          end
        end
      end

    end
  end
end

