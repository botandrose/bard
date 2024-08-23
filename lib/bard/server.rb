require "uri"
require "bard/command"
require "bard/copy"

module Bard
  class Server < Struct.new(:project_name, :key, :ssh, :path, :ping, :gateway, :ssh_key, :env)
    def self.define project_name, key, &block
      new(project_name, key).tap do |server|
        server.instance_eval &block
      end
    end

    def self.setting *fields
      fields.each do |field|
        define_method field do |*args|
          if args.length == 1
            send :"#{field}=", args.first
          elsif args.length == 0
            super()
          else
            raise ArgumentError
          end
        end
      end
    end

    setting :ssh, :path, :ping, :gateway, :ssh_key, :env

    def ping(*args)
      if args.length == 0
        (super() || [nil]).map(&method(:normalize_ping)).flatten
      else
        self.ping = args
      end
    end

    private def normalize_ping value
      return [] if value == false
      normalized = "https://#{ssh_uri.host}" # default if none specified
      if value =~ %r{^/}
        normalized += value
      elsif value.to_s.length > 0
        normalized = value
      end
      if normalized !~ /^http/
        normalized = "https://#{normalized}"
      end
      normalized
    end

    def path(*args)
      if args.length == 1
        self.path = args.first
      elsif args.length == 0
        super() || project_name
      else
        raise ArgumentError
      end
    end

    def ssh_uri which=:ssh
      value = send(which)
      URI("ssh://#{value}")
    end

    def scp_uri file_path=nil
      ssh_uri.dup.tap do |uri|
        uri.scheme = "scp"
        uri.path = "/#{path}"
        uri.path += "/#{file_path}" if file_path
      end
    end

    def rsync_uri file_path=nil
      ssh_uri.dup.tap do |uri|
        uri.scheme = nil
        uri.port = nil
        uri.path = ":#{path}"
        uri.path += "/#{file_path}" if file_path
      end.to_s[2..]
    end

    def with(attrs)
      dup.tap do |s|
        attrs.each do |key, value|
          s.send key, value
        end
      end
    end

    def to_sym
      key
    end

    def run! command, home: false, verbose: false, quiet: false
      Bard::Command.run! command, on: self, home:, verbose:, quiet:
    end

    def run command, home: false, verbose: false, quiet: false
      Bard::Command.run command, on: self, home:, verbose:, quiet:
    end

    def exec! command, home: false
      Bard::Command.exec! command, on: self, home:
    end

    def copy_file path, to:, verbose: false
      Bard::Copy.file path, from: self, to:, verbose:
    end

    def copy_dir path, to:, verbose: false
      Bard::Copy.dir path, from: self, to:, verbose:
    end
  end
end

