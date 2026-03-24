module Bard
  class Provision < Struct.new(:config, :ssh_url)
    def self.call(...) = new(...).call

    private

    def target
      config[:production]
    end

    def provision_server
      target.with(ssh: ssh_url)
    end
  end
end

