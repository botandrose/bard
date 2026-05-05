require "bard/plugins/deploy/strategy"
require "bard/copy"
require "bard/plugins/ssh"

module Bard
  class DeployStrategy
    class SSH < DeployStrategy
      def deploy(clone: nil, branch: nil, force: false)
        target.require_capability!(:ssh)

        if clone
          target.run! "git clone git@github.com:botandrosedesign/#{clone} #{target.path}", home: true
          Bard::Copy.file "config/master.key", from: target.config[:local], to: target
        elsif force
          target.run! "git fetch origin #{branch}"
          target.run! "git checkout -f origin/#{branch}"
        else
          branch ||= target.instance_variable_get(:@branch) || "master"
          target.run! "git pull --ff-only origin #{branch}"
        end

        target.run! "bin/setup"
        target.run! "bard setup" if clone
      end
    end
  end
end
