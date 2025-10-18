# move ssh port
# add to known hosts

class Bard::Provision::SSH < Bard::Provision
  def call
    print "SSH:"

    if password_auth_enabled?
      print " Disabling password authentication,"
      disable_password_auth!
    end

    if !ssh_available?(provision_server.ssh_uri, port: target_port)
      if !ssh_available?(provision_server.ssh_uri)
        raise "can't find SSH on port #{target_port} or #{provision_server.ssh_uri.port || 22}"
      end
      if !ssh_known_host?(provision_server.ssh_uri)
        print " Adding known host,"
        add_ssh_known_host!(provision_server.ssh_uri)
      end
      print " Reconfiguring port to #{target_port},"
      provision_server.run! %(echo "Port #{target_port}" | sudo tee /etc/ssh/sshd_config.d/port_#{target_port}.conf; sudo service ssh restart), home: true
    end

    if !ssh_known_host?(provision_server.ssh_uri)
      print " Adding known host,"
      add_ssh_known_host!(provision_server.ssh_uri)
    end

    # provision with new target port from now on
    ssh_url.gsub!(/:\d+$/, "")
    ssh_url << ":#{target_port}"
    puts " ✓"
  end

  private

  def target_port
    server.ssh_uri.port || 22
  end

  def ssh_available? ssh_uri, port: nil
    port ||= ssh_uri.port || 22
    system "nc -zv #{ssh_uri.host} #{port} 2>/dev/null"
  end

  def ssh_known_host? ssh_uri
    port ||= ssh_uri.port || 22
    system "grep -q \"$(ssh-keyscan -t ed25519 -p#{port} #{ssh_uri.host} 2>/dev/null | cut -d ' ' -f 2-3)\" ~/.ssh/known_hosts"
  end

  def add_ssh_known_host! ssh_uri
    port ||= ssh_uri.port || 22
    system "ssh-keyscan -p#{port} -H #{ssh_uri.host} >> ~/.ssh/known_hosts 2>/dev/null"
  end

  def password_auth_enabled?
    result = provision_server.run!(
      %q{grep -E '^\s*PasswordAuthentication\s+yes' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null || true},
      home: true,
      capture: true
    )
    !!(result && !result.strip.empty?)
  end

  def disable_password_auth!
    provision_server.run!(
      %q{echo "PasswordAuthentication no" | sudo tee /etc/ssh/sshd_config.d/disable_password_auth.conf; sudo service ssh restart},
      home: true
    )
  end
end
