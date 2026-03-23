# run bard deploy

class Bard::Provision::Deploy < Bard::Provision
  def call
    print "Deploy:"
    provision_server.run! "bin/setup"
    puts " ✓"
  end
end

