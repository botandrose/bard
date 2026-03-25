require "bard/target"
require "bard/plugins/url/target_methods"
require "bard/plugins/ssh/connection"

class Bard::Target
  def ssh(uri = nil, **options)
    if uri.nil?
      return @server
    else
      extend Bard::SSH

      @server = Bard::SSHServer.new(uri, **options)
      @path = options[:path] if options[:path]
      enable_capability(:ssh)

      hostname = @server.hostname
      url("https://#{hostname}") if hostname
    end
  end
end
