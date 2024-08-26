require "uri"

# test for existence

class Bard::Provision::HTTP < Bard::Provision
  def call
    print "HTTP:"
    target_host = URI.parse(server.ping.first).host
    if system "curl -s --resolve #{target_host}:80:#{provision_server.ssh_uri.host} http://#{target_host} -I | grep -i \"x-powered-by: phusion passenger\" >/dev/null 2>&1"
      puts " ✓"
    else
      puts " !!! not serving a rails app from #{provision_server.ssh_uri.host}"
    end
  end
end

