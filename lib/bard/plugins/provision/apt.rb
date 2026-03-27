# apt sanity

class Bard::Provision::Apt < Bard::Provision
  def call
    print "Apt:"
    provision_server.run! [
      %(echo "\\$nrconf{restart} = \\"a\\";" | sudo tee /etc/needrestart/conf.d/90-autorestart.conf),
      "sudo apt-get update -y",
      "sudo apt-get upgrade -y",
      "sudo apt-get install -y curl build-essential libsodium-dev",
    ].join("; "), home: true

    puts " ✓"
  end
end

