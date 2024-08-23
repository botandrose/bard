require "bard/command"

module Bard::CLI::Data
  def self.included mod
    mod.class_eval do

      desc "data --from=production --to=local", "copy database and assets from from to to"
      option :from, default: "production"
      option :to, default: "local"
      def data
        from = config[options[:from]]
        to = config[options[:to]]

        if to.key == :production
          url = to.ping.first
          puts yellow "WARNING: You are about to push data to production, overwriting everything that is there!"
          answer = ask("If you really want to do this, please type in the full HTTPS url of the production server:")
          if answer != url
            puts red("!!! ") + "Failed! We expected #{url}. Is this really where you want to overwrite all the data?"
            exit 1
          end
        end

        puts "Dumping #{from.key} database to file..."
        from.run! "bin/rake db:dump"

        puts "Transfering file from #{from.key} to #{to.key}..."
        from.copy_file "db/data.sql.gz", to: to, verbose: true

        puts "Loading file into #{to.key} database..."
        to.run! "bin/rake db:load"

        config.data.each do |path|
          puts "Synchronizing files in #{path}..."
          from.copy_dir path, to: to, verbose: true
        end
      rescue Bard::Command::Error => e
        puts red("!!! ") + "Running command failed: #{yellow(e.message)}"
        exit 1
      end

    end
  end
end

