# install mysql

class Bard::Provision::MySQL < Bard::Provision
  def call
    print "MySQL:"
    if !mysql_responding?
      print " Installing,"
      provision_server.run! [
        "sudo apt-get install -y mysql-server",
        %(sudo mysql -uroot -e "ALTER USER \\"'\\"root\\"'\\"@\\"'\\"localhost\\"'\\" IDENTIFIED WITH mysql_native_password BY \\"'\\"\\"'\\", \\"'\\"root\\"'\\"@\\"'\\"localhost\\"'\\" PASSWORD EXPIRE NEVER; FLUSH PRIVILEGES;"),
      ].join("; "), home: true
    end

    puts " ✓"
  end

  def mysql_responding?
    provision_server.run "sudo service mysql status | cat", quiet: true
  end
end



