require "uri"
require "bard/command"

module Bard
  class SSHServer
    attr_reader :user, :host, :port, :path, :gateway, :ssh_key, :env

    def initialize(uri_string, **options)
      @uri_string = uri_string
      @options = options

      # Parse URI
      uri = parse_uri(uri_string)
      @user = uri.user || ENV['USER']
      @host = uri.host
      @port = uri.port ? uri.port.to_s : "22"

      # Store options
      @path = options[:path]
      @gateway = options[:gateway]
      @ssh_key = options[:ssh_key]
      @env = options[:env]
    end

    def ssh_uri
      "#{user}@#{host}:#{port}"
    end

    def hostname
      host
    end

    def connection_string
      "#{user}@#{host}"
    end

    def run(command)
      full_command = build_command(command)
      Open3.capture3(full_command)
    end

    def run!(command)
      output, error, status = run(command)
      if status.to_i.nonzero?
        raise Command::Error, "Command failed: #{command}\n#{error}"
      end
      output
    end

    def exec!(command)
      full_command = build_command(command)
      exec(full_command)
    end

    private

    def parse_uri(uri_string)
      # Handle user@host:port format
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

    def build_command(command)
      cmd = "ssh -tt"

      # Add port
      cmd += " -p #{port}" if port != "22"

      # Add gateway
      cmd += " -o ProxyJump=#{gateway}" if gateway

      # Add SSH key
      cmd += " -i #{ssh_key}" if ssh_key

      # Add user@host
      cmd += " #{user}@#{host}"

      # Add command with path and env
      remote_cmd = ""
      remote_cmd += "#{env} " if env
      remote_cmd += "cd #{path} && " if path
      remote_cmd += command

      cmd += " '#{remote_cmd}'"
      cmd
    end
  end
end
