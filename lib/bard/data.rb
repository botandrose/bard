class Bard::CLI < Thor
  class Data < Struct.new(:bard, :from, :to)
    def call
      if to == "local"
        data_pull_db from.to_sym
        data_pull_assets from.to_sym
      end
      if from == "local"
        data_push_db to.to_sym
        data_push_assets to.to_sym
      end
    end

    private

    def data_pull_db server
      bard.instance_eval do
        run_crucial ssh_command(server, "bin/rake db:dump && gzip -9f db/data.sql")
        copy :from, server, "db/data.sql.gz"
        run_crucial "gunzip -f db/data.sql.gz && bin/rake db:load"
      end
    end

    def data_push_db server
      bard.instance_eval do
        run_crucial "bin/rake db:dump && gzip -9f db/data.sql"
        copy :to, server, "db/data.sql.gz"
        run_crucial ssh_command(server, "gunzip -f db/data.sql.gz && bin/rake db:load")
      end
    end

    def data_pull_assets server
      bard.instance_eval do
        @config.data.each do |path|
          rsync :from, server, path
        end
      end
    end

    def data_push_assets server
      bard.instance_eval do
        @config.data.each do |path|
          rsync :to, server, path
        end
      end
    end
  end
end

