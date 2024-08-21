# copy data from production

class Bard::Provision::Data < Bard::Provision
  def call
    print "Data:"

    # print " Dumping #{server.key} database to file"
    # server.run! "bin/rake db:dump"

    # print " Transfering file from #{server.key},"
    # server.copy_file "db/data.sql.gz", to: provision_server, verbose: false

    # print " Loading file into database,"
    # provision_server.run! "bin/rake db:load"

    data.each do |path|
      print " Synchronizing files in #{path},"
      server.copy_dir path, to: provision_server, verbose: false
    end

    puts " ✓"
  end
end




