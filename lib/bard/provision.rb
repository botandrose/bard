module Bard
  class Provision < Struct.new(:config, :ssh_url)
    def self.call(...) = new(...).call

    def call
      SSH.call(*values)
      User.call(*values)
      Apt.call(*values)
      MySQL.call(*values)
      Repo.call(*values)
      MasterKey.call(*values)
      RVM.call(*values)
      App.call(*values)
      Passenger.call(*values)
      Data.call(*values)
      HTTP.call(*values)
    end

    private

    def server
      config[:production]
    end

    def provision_server
      server.with(ssh: ssh_url)
    end
  end
end

require "bard/provision/ssh"
require "bard/provision/user"
require "bard/provision/apt"
require "bard/provision/mysql"
require "bard/provision/repo"
require "bard/provision/master_key"
require "bard/provision/rvm"
require "bard/provision/app"
require "bard/provision/passenger"
require "bard/provision/data"
require "bard/provision/http"

