require "bard/server"

module Bard
  class Config
    def self.current(working_directory: Dir.getwd)
      project_name = File.basename(working_directory)
      path = File.join(working_directory, "bard.rb")
      new(project_name, path: path)
    end

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
        @backup = BackupConfig.new { disabled }
      elsif value.nil? # Getter
        @backup ||= BackupConfig.new { bard }
      else
        raise ArgumentError, "backup accepts false or a block"
      end
    end

    # short-hand for michael

    def github_pages url
      urls = []
      uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
      hostname = uri.hostname.sub(/^www\./, '')
      urls = [hostname]
      if hostname.count(".") < 2
        urls << "www.#{hostname}"
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
    attr_reader :destinations

    def initialize(&block)
      @destinations = []
      instance_eval(&block) if block_given?
    end

    def bard
      @bard = true
    end

    def bard?
      !!@bard
    end

    def disabled
      @disabled = true
    end

    def disabled?
      !!@disabled
    end

    def enabled?
      !disabled?
    end

    def s3(name, **kwargs)
      @destinations << {
        name: name,
        type: :s3,
        **kwargs,
      }
    end

    def self_managed?
      @destinations.any?
    end
  end
end
