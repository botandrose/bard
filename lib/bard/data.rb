require "bard/command"
require "bard/copy"

module Bard
  class Data < Struct.new(:paths, :from, :to)
    def self.call paths, from:, to:
      new(paths, from, to).call
    end

    def call
      copy_database
      copy_files
    end

    private

    def copy_database
      puts "Dumping #{from.key} database to file..."
      Bard::Command.run! "bin/rake db:dump", on: from

      puts "Transfering file from #{from.key} to #{to.key}..."
      Bard::Copy.file "db/data.sql.gz", from: from, to: to, verbose: true

      puts "Loading file into #{to.key} database..."
      Bard::Command.run! "bin/rake db:load", on: to
    end

    def copy_files
      paths.each do |path|
        puts "Synchronizing files in #{path}..."
        Bard::Copy.dir path, from: from, to: to, verbose: true
      end
    end
  end
end

