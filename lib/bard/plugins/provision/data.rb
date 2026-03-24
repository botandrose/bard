# copy data from production

class Bard::Provision::Data < Bard::Provision
  def call
    print "Data:"

    print " Dumping #{target.key} database to file"
    target.run! "bin/rake db:dump"

    print " Transfering file from #{target.key},"
    target.copy_file "db/data.sql.gz", to: provision_server, verbose: false

    print " Loading file into database,"
    provision_server.run! "bin/rake db:load"

    config.data.each do |path|
      print " Synchronizing files in #{path},"
      target.copy_dir path, to: provision_server, verbose: false
    end

    puts " ✓"
  end
end




