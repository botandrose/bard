require "bard/deploy_strategy"

module Bard
  class DeployStrategy
    class SSH < DeployStrategy
      def deploy
        # Require SSH capability
        target.require_capability!(:ssh)

        # Determine branch
        branch = target.instance_variable_get(:@branch) || "master"

        # Run git pull and setup on remote server
        target.run! "git pull origin #{branch}"
        target.run! "bin/setup"
      end
    end
  end
end
