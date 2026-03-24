module Bard
  module Plugin
    class << self
      def load!
        load_builtins
        load_externals
      end

      private

      def load_builtins
        Dir[File.join(__dir__, "plugins", "*.rb")].sort.each { |f| require f }
      end

      def load_externals
        Dir[File.join(Dir.pwd, "lib", "bard", "plugins", "*.rb")].sort.each { |f| require f }
      end
    end
  end
end
