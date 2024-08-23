require "bard/server"

module Bard
  class Config
    def initialize project_name, path: nil, source: nil
      @project_name = project_name
      @servers = {
        local: Server.new(
          project_name,
          :local,
          false,
          "./",
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
      if path && File.exist?(path)
        source = File.read(path)
      end
      if source
        instance_eval source
      end
    end

    attr_reader :project_name, :servers

    def server key, &block
      key = key.to_sym
      @servers[key] = Server.define(project_name, key, &block)
    end

    def [] key
      key = key.to_sym
      if @servers[key].nil? && key == :production
        key = :staging
      end
      @servers[key]
    end

    def data *paths
      if paths.length == 0
        Array(@data)
      else
        @data = paths
      end
    end

    def backup *args
      if args.length == 1
        @backup = args.first
      elsif args.length == 0
        return @backup if defined?(@backup)
        @backup = true
      else
        raise ArgumentError
      end
    end
  end
end
