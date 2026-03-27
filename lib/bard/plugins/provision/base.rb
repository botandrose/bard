module Bard
  class Provision < Struct.new(:config, :ssh_url)
    def self.call(...) = new(...).call

    private

    def target
      config[:production]
    end

    def provision_server
      options = {}
      options[:ssh_key] = target.ssh.ssh_key if target.ssh&.ssh_key
      target.dup.tap { |t| t.ssh(ssh_url, **options) }
    end
  end
end

