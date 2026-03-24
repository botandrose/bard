require "bard/plugins/provision/base"

class Bard::CLI
  PROVISION_STEPS = %w[
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
  option :steps, type: :array, default: PROVISION_STEPS
  def provision(ssh_url = config[:production].ssh&.to_s)
    ssh_url = ssh_url.dup
    options[:steps].each do |step|
      require "bard/plugins/provision/#{step.downcase}"
      Bard::Provision.const_get(step).call(config, ssh_url)
    end
  end
end
