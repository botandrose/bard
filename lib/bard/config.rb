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
          ["#{project_name}.local"],
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
          "jenkins@staging.botandrose.com:22022",
          "jobs/#{project_name}/workspace",
          false,
        ),
        staging: Server.new(
          project_name,
          :staging,
          "www@staging.botandrose.com:22022",
          project_name,
          ["#{project_name}.botandrose.com"],
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

    def backup(value = nil, &block)
      if block_given?
        @backup = BackupConfig.new(&block)
      elsif value == false
        @backup = false
      elsif value == true
        # Backward compatibility: backup true
        @backup = BackupConfig.new { bard }
      elsif value.nil?
        # Getter
        return @backup if defined?(@backup)
        @backup = BackupConfig.new { bard }  # Default
      else
        raise ArgumentError, "backup accepts a block, true, or false"
      end
    end

    # short-hand for michael

    def github_pages url=nil
      urls = []
      if url.present?
        uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
        hostname = uri.hostname.sub(/^www\./, '')
        urls = [hostname]
        if hostname.count(".") < 2
          urls << "www.#{hostname}"
        end
      end

      server :production do
        github_pages true
        ssh false
        ping *urls
      end

      backup false
    end
  end

  class BackupConfig
    attr_reader :bard_enabled, :destinations

    def initialize(&block)
      @bard_enabled = false
      @destinations = []
      instance_eval(&block) if block_given?
    end

    def bard
      @bard_enabled = true
    end

    def s3(name, credentials:, path:)
      @destinations << {
        name: name,
        type: :s3,
        credentials: credentials,
        path: path
      }
    end

    def bard?
      @bard_enabled
    end

    def self_managed?
      @destinations.any?
    end
  end
end
