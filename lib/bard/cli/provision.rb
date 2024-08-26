require "bard/provision"

module Bard::CLI::Provision
  def self.included mod
    mod.class_eval do

      desc "provision [ssh_url]", "takes an optional ssh url to a raw ubuntu 22.04 install, and readies it in the shape of :production"
      def provision ssh_url=config[:production].ssh
        Bard::Provision.call(config, ssh_url.dup) # dup unfreezes the string for later mutation
      end

    end
  end
end

