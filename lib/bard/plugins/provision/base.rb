module Bard
  class Provision < Struct.new(:config, :ssh_url)
    def self.call(...) = new(...).call

    private

    def server
      config[:production]
    end

    def provision_server
      server.with(ssh: ssh_url)
    end
  end
end

