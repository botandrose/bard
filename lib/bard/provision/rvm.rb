# install rvm if missing

class Bard::Provision::RVM < Bard::Provision
  def call
    print "RVM:"
    if !provision_server.run "[ -d ~/.rvm ]", quiet: true
      print " Installing RVM,"
      provision_server.run! [
        %(sed -i "1i[[ -s \\"$HOME/.rvm/scripts/rvm\\" ]] && source \\"$HOME/.rvm/scripts/rvm\\" # Load RVM into a shell session *as a function*" ~/.bashrc),
        "gpg --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB",
        "curl -sSL https://get.rvm.io | bash -s stable",
      ].join("; ")
      print " Installing Ruby #{File.read(".ruby-version")},"
      provision_server.run! "rvm install ."
    end

    puts " ✓"
  end
end


