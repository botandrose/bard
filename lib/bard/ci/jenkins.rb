require "json"
require "bard/ci/runner"
require "bard/secrets"

module Bard
  class CI
    class Jenkins < Runner
      def exists?
        `curl -s -I #{ci_host}/` =~ /\b200 OK\b/
      end

      def create!
        git_url = `git remote get-url origin`.strip
        config = JOB_CONFIG_XML.sub("GIT_URL", git_url)
        `curl -s -X POST "http://#{auth}@ci.botandrose.com/createItem?name=#{project_name}" -H "Content-Type: application/xml" -d '#{config}'`
      end

      def console
        raw = `curl -s #{ci_host}/lastBuild/console`
        raw[%r{<pre.*?>(.+)</pre>}m, 1]
      end

      attr_accessor :last_response

      protected

      def wait_until_started
        sleep(2) until started?
      end

      def start
        command = "curl -s -I -X POST -L '#{ci_host}/buildWithParameters?GIT_REF=#{branch}'"
        output = `#{command}`
        @queueId = output[%r{Location: .+/queue/item/(\d+)/}, 1].to_i
      end

      def building?
        retry_with_backoff do
          self.last_response = `curl -s #{ci_host}/#{job_id}/api/json?tree=building,result`
          raise "Blank response from CI" if last_response.empty?
        end
        last_response.include? '"building":true'
      end

      def success?
        last_response.include? '"result":"SUCCESS"'
      end

      def get_state_data
        {
          "project_name" => project_name,
          "branch" => branch,
          "queue_id" => @queueId,
          "job_id" => @job_id,
          "start_time" => @start_time,
          "last_time_elapsed" => @last_time_elapsed
        }
      end

      def restore_state(data)
        @queueId = data["queue_id"]
        @job_id = data["job_id"]
        @start_time = data["start_time"]
        @last_time_elapsed = data["last_time_elapsed"]
      end

      private

      def get_last_time_elapsed
        response = retry_with_backoff do
          response = `curl -s #{ci_host}/lastStableBuild/api/xml`
          raise "Blank response from CI" if response.empty?
          response
        end
        response.match(/<duration>(\d+)<\/duration>/)
        $1 ? $1.to_i / 1000 : nil
      rescue => e
        puts "  Warning: Could not get last build duration: #{e.message}"
        nil
      end

      def auth
        @auth ||= "#{Bard::Secrets.fetch("jenkins-user")}:#{Bard::Secrets.fetch("jenkins-token")}"
      end

      def ci_host
        "http://#{auth}@ci.botandrose.com/job/#{project_name}"
      end

      def started?
        retry_with_backoff do
          command = "curl -s -g '#{ci_host}/api/json?depth=1&tree=builds[queueId,number]'"
          output = `#{command}`
          raise "Blank response from CI" if output.empty?
          builds = JSON.parse(output)["builds"]
          raise "Build not found in builds list" if builds.empty?
          builds.first["queueId"] == @queueId
        end
      end

      def job_id
        @job_id ||= begin
          retry_with_backoff do
            output = `curl -s -g '#{ci_host}/api/json?depth=1&tree=builds[queueId,number]'`
            raise "Blank response from CI" if output.empty?
            builds = JSON.parse(output)["builds"]
            build = builds.find { |b| b["queueId"] == @queueId }
            build["number"]
          end
        end
      end
      JOB_CONFIG_XML = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <project>
          <actions/>
          <description></description>
          <keepDependencies>false</keepDependencies>
          <properties>
            <hudson.model.ParametersDefinitionProperty>
              <parameterDefinitions>
                <hudson.model.StringParameterDefinition>
                  <name>GIT_REF</name>
                  <description></description>
                  <defaultValue>master</defaultValue>
                </hudson.model.StringParameterDefinition>
              </parameterDefinitions>
            </hudson.model.ParametersDefinitionProperty>
          </properties>
          <scm class="hudson.plugins.git.GitSCM" plugin="git@3.3.0">
            <configVersion>2</configVersion>
            <userRemoteConfigs>
              <hudson.plugins.git.UserRemoteConfig>
                <url>GIT_URL</url>
              </hudson.plugins.git.UserRemoteConfig>
            </userRemoteConfigs>
            <branches>
              <hudson.plugins.git.BranchSpec>
                <name>$GIT_REF</name>
              </hudson.plugins.git.BranchSpec>
            </branches>
            <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
            <submoduleCfg class="list"/>
            <extensions/>
          </scm>
          <canRoam>true</canRoam>
          <disabled>false</disabled>
          <blockBuildWhenDownstreamBuilding>false</blockBuildWhenDownstreamBuilding>
          <blockBuildWhenUpstreamBuilding>false</blockBuildWhenUpstreamBuilding>
          <triggers/>
          <concurrentBuild>false</concurrentBuild>
          <builders>
            <hudson.tasks.Shell>
              <command>bash -l -c &quot;bin/setup &amp;&amp; bin/ci&quot;</command>
            </hudson.tasks.Shell>
          </builders>
          <publishers/>
          <buildWrappers/>
        </project>
      XML
    end
  end
end

