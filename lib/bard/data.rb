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
        puts "Dumping remote database to file..."
        run_crucial ssh_command(server, "bin/rake db:dump")

        puts "Downloading file..."
        copy :from, server, "db/data.sql.gz", verbose: true

        puts "Loading file into local database..."
        run_crucial "bin/rake db:load"
      end
    end

    def data_push_db server
      bard.instance_eval do
        puts "Dumping local database to file..."
        run_crucial "bin/rake db:dump"

        puts "Uploading file..."
        copy :to, server, "db/data.sql.gz", verbose: true

        puts "Loading file into remote database..."
        run_crucial ssh_command(server, "bin/rake db:load")
      end
    end

    def data_pull_assets server
      bard.instance_eval do
        @config.data.each do |path|
          puts "Downloading files..."
          rsync :from, server, path, verbose: true
        end
      end
    end

    def data_push_assets server
      bard.instance_eval do
        @config.data.each do |path|
          puts "Uploading files..."
          rsync :to, server, path, verbose: true
        end
      end
    end
  end
end

