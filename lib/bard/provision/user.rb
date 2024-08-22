# rename user

class Bard::Provision::User < Bard::Provision
  def call
    print "User:"

    if !ssh_with_user?(provision_server.ssh_uri, user: new_user)
      if !ssh_with_user?(provision_server.ssh_uri)
        raise "can't ssh in with user #{new_user} or #{old_user}"
      end
      print " Adding user #{new_user},"
      provision_server.run! [
        "sudo useradd -m -s /bin/bash #{new_user}",
        "sudo usermod -aG sudo #{new_user}",
        "echo \"#{new_user} ALL=(ALL) NOPASSWD:ALL\" | sudo tee -a /etc/sudoers",
        "sudo mkdir -p ~#{new_user}/.ssh",
        "sudo cp ~/.ssh/authorized_keys ~#{new_user}/.ssh/authorized_keys",
        "sudo chown -R #{new_user}:#{new_user} ~#{new_user}/.ssh",
      ].join("; "), home: true
    end

    # provision with new user from now on
    ssh_url.gsub!("#{old_user}@", "#{new_user}@")
    puts " ✓"
  end

  private

  def new_user
    server.ssh_uri.user
  end

  def old_user
    provision_server.ssh_uri.user
  end

  def ssh_with_user? ssh_uri, user: ssh_uri.user
    system "ssh -o ConnectTimeout=2 -p#{ssh_uri.port || 22} #{user}@#{ssh_uri.host} exit >/dev/null 2>&1"
  end
end

