require "bard/target"
require "bard/plugins/ssh/target_methods"
require "bard/plugins/ping/target_methods"
require "bard/plugins/deploy_url/target_methods"

module Bard
  class Config
    class << self
      attr_accessor :default_targets
      attr_accessor :strict
    end

    def self.current
      new(detect_project_name, path: "bard.rb")
    end

    def self.detect_project_name
      git_common_dir = `git rev-parse --git-common-dir 2>/dev/null`.chomp
      dirname = if $?.success? && !git_common_dir.empty?
        File.dirname(File.expand_path(git_common_dir))
      else
        Dir.getwd
      end
      File.basename(dirname)
    end

    attr_reader :project_name, :targets

    def initialize(project_name = nil, path: nil, source: nil)
      @project_name = project_name
      @targets = {}
      load_defaults if project_name

      if path && File.exist?(path)
        source = File.read(path)
      end
      if source
        instance_eval(source, path)
      end
    end

    def remove_target(key)
      @targets.delete(key.to_sym)
    end

    def target(key, &block)
      key = key.to_sym
      unless @targets[key].is_a?(Target)
        @targets[key] = Target.new(key, self)
      end
      @targets[key].instance_eval(&block) if block
      @targets[key]
    end

    def [](key)
      @targets[key.to_sym]
    end

    # A bard.rb may use DSL contributed by plugins. When the owning plugin is loaded it defines
    # a real method that wins over this; otherwise we tolerate the declaration as a plain
    # attribute so the file still parses — notably server-side, where bard-cli is absent.
    def method_missing(name, *args, &block)
      return super if self.class.strict
      if args.empty? && block.nil?
        (@attributes ||= {})[name]
      else
        (@attributes ||= {})[name] = args.length == 1 ? args.first : args
      end
    end

    def respond_to_missing?(name, include_private = false)
      !self.class.strict || super
    end

    private

    def load_defaults
      target :local
      Bard::Config.default_targets&.call(self)
    end
  end
end
