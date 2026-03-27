# install nginx

class Bard::Provision::Nginx < Bard::Provision
  def call
    print "Nginx:"
    if !http_responding?
      print " Installing nginx,"
      provision_server.run! [
        %(grep -qxF "RAILS_ENV=production" /etc/environment || echo "RAILS_ENV=production" | sudo tee -a /etc/environment),
        %(grep -qxF "EDITOR=vim" /etc/environment || echo "EDITOR=vim" | sudo tee -a /etc/environment),
        "sudo apt-get install -y nginx",
        "sudo rm -f /etc/nginx/sites-enabled/default",
      ].join("; "), home: true
    end

    if !app_configured?
      print " Creating nginx config for app,"
      provision_server.run! "bard setup"
    end

    puts " ✓"
  end

  def http_responding?
    provision_server.run "nc -zv localhost 80 2>/dev/null", home: true, quiet: true
  end

  def app_configured?
    provision_server.run "[ -f /etc/nginx/sites-enabled/#{config.project_name} ]", quiet: true
  end
end
