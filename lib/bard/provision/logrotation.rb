# install log rotation if missing

class Bard::Provision::LogRotation < Bard::Provision
  def call
    print "Log Rotation:"

    provision_server.run! <<~SH, quiet: true
      file=/etc/logrotate.d/#{server.project_name}
      if [ ! -f $file ]; then
        sudo tee $file > /dev/null <<EOF
      $(pwd)/log/*.log {
        weekly
        size 100M
        missingok
        rotate 52
        delaycompress
        notifempty
        copytruncate
        create 664 www www
      }
      EOF
      fi
    SH

    puts " ✓"
  end
end



