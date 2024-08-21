module Bard
  class Provision < Struct.new(:server, :data)
    def self.call(...) = new(...).call

    def call
      SSH.call(server)
      User.call(server)
      MySQL.call(server)
      Repo.call(server)
      MasterKey.call(server)
      RVM.call(server)
      App.call(server)
      Passenger.call(server)
      Data.call(server, data)
    end

    private

    def provision_server
      server.with(ssh: server.provision)
    end
  end
end

require "bard/provision/ssh"
require "bard/provision/user"
require "bard/provision/mysql"
require "bard/provision/passenger"
require "bard/provision/repo"
require "bard/provision/master_key"
require "bard/provision/rvm"
require "bard/provision/app"
require "bard/provision/data"

