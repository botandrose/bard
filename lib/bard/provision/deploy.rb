# run bard deploy

class Bard::Provision::Deploy < Bard::Provision
  def call
    print "Deploy:"
    config[:local].run! "bard deploy"
    puts " ✓"
  end
end

