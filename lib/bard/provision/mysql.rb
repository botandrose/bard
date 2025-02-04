# install mysql

class Bard::Provision::MySQL < Bard::Provision
  def call
    print "MySQL:"
    if !mysql_responding?
      print " Installing,"
      provision_server.run! [
        "sudo apt-get install -y mysql-server",
        %(sudo mysql -uroot -e "ALTER USER \\"'\\"root\\"'\\"@\\"'\\"localhost\\"'\\" IDENTIFIED WITH mysql_native_password BY \\"'\\"\\"'\\", \\"'\\"root\\"'\\"@\\"'\\"localhost\\"'\\" PASSWORD EXPIRE NEVER; FLUSH PRIVILEGES;"),
        %(mysql -uroot -e "UPDATE mysql.user SET password_lifetime = NULL WHERE user = 'root' AND host = 'localhost';"),
      ].join("; "), home: true
    end

    puts " ✓"
  end

  def mysql_responding?
    provision_server.run "sudo systemctl is-active --quiet mysql", home: true, quiet: true
  end
end

