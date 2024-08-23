module Bard::CLI::Open
  def self.included mod
    mod.class_eval do

      desc "open [server=production]", "opens the url in the web browser."
      def open server=:production
        exec "xdg-open #{config[server].ping.first}"
      end

    end
  end
end

