module Bard
  # Default configuration that is loaded before user's bard.rb
  # Users can override any of these targets in their bard.rb
  DEFAULT_CONFIG = lambda do |config, project_name|
    # Local development target
    config.instance_eval do
      target :local do
        ssh false
        path "./"
        ping "#{project_name}.local"
      end

      # Bot and Rose cloud server
      target :gubs do
        ssh "botandrose@cloud.hackett.world:22022",
          path: "Sites/#{project_name}"
        ping false
      end

      # CI target (Jenkins)
      target :ci do
        ssh "jenkins@staging.botandrose.com:22022",
          path: "jobs/#{project_name}/workspace"
        ping false
      end

      # Staging server
      target :staging do
        ssh "www@staging.botandrose.com:22022",
          path: project_name
        ping "#{project_name}.botandrose.com"
      end
    end
  end
end
