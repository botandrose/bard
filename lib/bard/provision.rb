module Bard
  class Provision < Struct.new(:config, :ssh_url)
    def self.call(...) = new(...).call

    def call
      %w[SSH User AuthorizedKeys Apt MySQL Repo MasterKey RVM App Passenger Data HTTP LogRotation Deploy].each do |step|
        require "bard/provision/#{step.downcase}"
        self.class.const_get(step).call(*values)
      end
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

