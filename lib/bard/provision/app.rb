# run bin/setup

class Bard::Provision::App < Bard::Provision
  def call
    print "App:"
    provision_server.run! "bin/setup"
    puts " ✓"
  end
end

