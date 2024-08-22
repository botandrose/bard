# test for existence

class Bard::Provision::HTTP < Bard::Provision
  def call
    print "HTTP:"
    target_host = URI.parse(server.ping.first).host
    if system "curl -s --resolve #{target_host}:80:#{provision_server.ssh_uri.host} http://#{target_host} -I | grep -i \"x-powered-by: phusion passenger\""
      puts " ✓"
    else
      puts " !!! not serving a rails app from #{provision_server.ssh_uri.host}"
    end
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

