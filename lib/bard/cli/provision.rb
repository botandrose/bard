require "bard/cli/command"
require "bard/provision"

class Bard::CLI::Provision < Bard::CLI::Command
  STEPS = %w[
    SSH
    User
    AuthorizedKeys
    Swapfile
    Apt
    MySQL
    Repo
    MasterKey
    RVM
    App
    Passenger
    HTTP
    LogRotation
    Data
    Deploy
  ]

  desc "provision [ssh_url] --steps=all", "takes an optional ssh url to a raw ubuntu 22.04 install, and readies it in the shape of :production"
  option :steps, type: :array, default: STEPS
  def provision ssh_url=config[:production].ssh&.to_s
    # unfreeze the string for later mutation
    ssh_url = ssh_url.dup
    options[:steps].each do |step|
      require "bard/provision/#{step.downcase}"
      Bard::Provision.const_get(step).call(config, ssh_url)
    end
  end
end

