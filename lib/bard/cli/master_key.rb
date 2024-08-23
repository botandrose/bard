module Bard::CLI::MasterKey
  def self.included mod
    mod.class_eval do

      desc "master_key --from=production --to=local", "copy master key from from to to"
      option :from, default: "production"
      option :to, default: "local"
      def master_key
        from = config[options[:from]]
        to = config[options[:to]]
        from.copy_file "config/master.key", to:
      end

    end
  end
end

