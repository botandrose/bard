# install nginx & passenger

class Bard::Provision::Passenger < Bard::Provision
  def call
    print "Passenger:"
    if !http_responding?
      print " Installing nginx & Passenger,"
      provision_server.run! [
        %(echo "\\$nrconf{restart} = \\"a\\";" | sudo tee /etc/needrestart/conf.d/90-autorestart.conf),
        %(grep -qxF "RAILS_ENV=production" /etc/environment || echo "RAILS_ENV=production" | sudo tee -a /etc/environment),
        %(grep -qxF "EDITOR=vim" /etc/environment || echo "EDITOR=vim" | sudo tee -a /etc/environment),
        "sudo apt-get update -y",
        "sudo apt-get upgrade -y",
        "sudo apt-get install -y vim dirmngr gnupg apt-transport-https ca-certificates curl",
        "curl https://oss-binaries.phusionpassenger.com/auto-software-signing-gpg-key.txt | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/phusion.gpg >/dev/null",
        %(echo "deb https://oss-binaries.phusionpassenger.com/apt/passenger jammy main" | sudo tee /etc/apt/sources.list.d/passenger.list),
        "sudo apt-get update -y",
        "sudo apt-get install -y nginx libnginx-mod-http-passenger",
      ].join("; "), home: true
    end

    if !app_configured?
      print " Creating nginx config for app,"
      provision_server.run! "bard setup"
    end

    puts " ✓"
  end

  def http_responding?
    system "nc -zv #{provision_server.ssh_uri.host} 80 2>/dev/null"
  end

  def app_configured?
    provision_server.run "[ -f /etc/nginx/sites-enabled/#{server.project_name} ]", quiet: true
  end
end


