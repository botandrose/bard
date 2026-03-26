require "uri"

# test for existence

class Bard::Provision::HTTP < Bard::Provision
  def call
    print "HTTP:"
    target_host = URI.parse(target.url).host
    if system "curl -sf --resolve #{target_host}:80:#{provision_server.ssh_uri.host} http://#{target_host} -o /dev/null"
      puts " ✓"
    else
      puts " !!! not serving a rails app from #{provision_server.ssh_uri.host}"
    end
  end
end

