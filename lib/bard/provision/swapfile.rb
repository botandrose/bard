# setup swapfile

class Bard::Provision::Swapfile < Bard::Provision
  def call
    print "Swapfile:"

    provision_server.run! <<~BASH
      if [ ! -f /swapfile ]; then
        sudo fallocate -l $(grep MemTotal /proc/meminfo | awk '{print $2}')K /swapfile
      fi
      sudo chmod 600 /swapfile
      sudo swapon --show | grep -q '/swapfile' || sudo mkswap /swapfile
      sudo swapon --show | grep -q '/swapfile' || sudo swapon /swapfile
      grep -q '/swapfile none swap sw 0 0' /etc/fstab || echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    BASH

    puts " ✓"
  end
end


