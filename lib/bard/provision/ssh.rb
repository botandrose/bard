# move ssh port
# add to known hosts

class Bard::Provision::SSH < Bard::Provision
  def call
    print "SSH:"

    if !ssh_available?(provision_server.ssh_uri, port: server.ssh_uri.port)
      if !ssh_available?(provision_server.ssh_uri)
        raise "can't find SSH on port #{server.ssh_uri.port} or #{provision_server.ssh_uri.port}"
      end
      if !ssh_known_host?(provision_server.ssh_uri)
        print " Adding known host,"
        add_ssh_known_host!(provision_server.ssh_uri)
      end
      print " Reconfiguring port to #{server.ssh_uri.port},"
      provision.server.run! %(echo "Port #{server.ssh_uri.port}" | sudo tee /etc/ssh/sshd_config.d/port_22022.conf; sudo service ssh restart), home: true
    end

    if !ssh_known_host?(provision_server.ssh_uri)
      print " Adding known host,"
      add_ssh_known_host!(provision_server.ssh_uri)
    end

    # provision with new port from now on
    ssh_url.gsub!(/:\d+$/, "")
    ssh_url << ":#{server.ssh_uri.port}"
    puts " ✓"
  end
  
  private

  def ssh_available? ssh_uri, port: ssh_uri.port
    system "nc -zv #{ssh_uri.host} #{port} 2>/dev/null"
  end

  def ssh_known_host? ssh_uri
    system "grep -q \"$(ssh-keyscan -t ed25519 -p#{ssh_uri.port || 22} #{ssh_uri.host} 2>/dev/null | cut -d ' ' -f 2-3)\" ~/.ssh/known_hosts"
  end

  def add_ssh_known_host! ssh_uri
    system "ssh-keyscan -p#{ssh_uri.port || 22} -H #{ssh_uri.host} >> ~/.ssh/known_hosts"
  end
end
