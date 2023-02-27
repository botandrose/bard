require "uri"

class Bard::CLI < Thor
  class Config
    def initialize project_name, path
      @project_name = project_name
      @servers = {
        local: Server.new(
          project_name,
          :local,
          false,
          "./",
          false,
        ),
        theia: Server.new(
          project_name,
          :theia,
          "gubito@gubs.pagekite.me",
          "Sites/#{project_name}",
          false,
        ),
        gubs: Server.new(
          project_name,
          :gubs,
          "botandrose@cloud.hackett.world:22022",
          "Sites/#{project_name}",
          false,
        ),
        ci: Server.new(
          project_name,
          :ci,
          "jenkins@ci.botandrose.com:22022",
          "jobs/#{project_name}/workspace",
          false,
        ),
        staging: Server.new(
          project_name,
          :staging,
          "www@#{project_name}.botandrose.com:22022",
        ),
      }
      load_local_config! path
    end

    attr_reader :servers

    def server key, &block
      @servers[key] ||= Server.new(@project_name, key)
      @servers[key].instance_eval &block if block_given?
      @servers[key]
    end

    def data *paths
      if paths.length == 0
        Array(@data)
      else
        @data = paths
      end
    end

    private

    def load_local_config! path
      instance_eval File.read(File.expand_path(path)) if File.exist?(path)
    end

    class Server < Struct.new(:project_name, :key, :ssh, :path, :ping, :gateway, :ssh_key, :env)
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

      def default_ping
        uri = URI.parse("ssh://#{ssh}")
        "http://#{uri.host}"
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
    end
  end
end
