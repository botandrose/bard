require "uri"
require "bard/command"
require "bard/copy"

module Bard
  class Server < Struct.new(:project_name, :key, :ssh, :path, :ping, :gateway, :ssh_key, :env, :provision)
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

    setting :ssh, :path, :ping, :gateway, :ssh_key, :env, :provision

    def ping(*args)
      if args.length == 0
        (super() || [nil]).map(&method(:normalize_ping))
      else
        self.ping = args
      end
    end

    private def normalize_ping value
      return value if value == false
      uri = URI.parse("ssh://#{ssh}")
      normalized = "https://#{uri.host}" # default if none specified
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
      URI.parse("ssh://#{value}")
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

