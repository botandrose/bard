require "uri"

module Bard
  class SSHServer
    attr_reader :user, :host, :port, :path, :gateway, :ssh_key, :env

    def initialize(uri_string, **options)
      @uri_string = uri_string
      @options = options

      uri = parse_uri(uri_string)
      @user = uri.user || ENV['USER']
      @host = uri.host
      @port = uri.port ? uri.port.to_s : "22"

      @path = options[:path]
      @gateway = options[:gateway]
      @ssh_key = options[:ssh_key]
      @env = options[:env]
    end

    def ssh_uri
      URI("ssh://#{user}@#{host}:#{port}")
    end

    def hostname
      host
    end

    def to_s
      str = "#{user}@#{host}"
      str += ":#{port}" if port && port != "22"
      str
    end

    def connection_string
      "#{user}@#{host}"
    end

    def ==(other)
      return false unless other.is_a?(Bard::SSHServer)
      state == other.state
    end
    alias_method :eql?, :==

    def hash
      state.hash
    end

    protected

    def state
      [user, host, port, path, gateway, ssh_key, env]
    end

    private

    def parse_uri(uri_string)
      if uri_string =~ /^([^@]+@)?([^:]+)(?::(\d+))?$/
        user_part = $1&.chomp('@')
        host_part = $2
        port_part = $3

        URI::Generic.build(
          scheme: 'ssh',
          userinfo: user_part,
          host: host_part,
          port: port_part&.to_i
        )
      else
        URI.parse("ssh://#{uri_string}")
      end
    end
  end
end
