require "bard/plugins/deploy/strategy"
require "bard/plugins/ssh"

module Bard
  class DeployStrategy
    class SSH < DeployStrategy
      def deploy(clone: nil)
        target.require_capability!(:ssh)

        if clone
          target.run! "git clone git@github.com:botandrosedesign/#{clone} #{target.path}", home: true
          target.config[:local].copy_file "config/master.key", to: target
        else
          branch = target.instance_variable_get(:@branch) || "master"
          target.run! "git pull origin #{branch}"
        end

        target.run! "bin/setup"
        target.run! "bard setup" if clone
      end
    end
  end
end
