require "json"
require "forwardable"
require "open3"

class Bard::CLI < Thor
  class CI
    def initialize project_name, sha, local: false
      @project_name = project_name
      @sha = sha
      @local = !!local
      @runner = @local ? Local.new(project_name, sha) : Remote.new(project_name, sha)
    end

    attr_reader :project_name, :sha, :runner

    def local?
      @local
    end

    extend Forwardable

    delegate [:run, :exists?, :console, :last_response] => :runner

    class Remote < Struct.new(:project_name, :sha)
      def run
        last_time_elapsed = get_last_time_elapsed
        start
        sleep(2) until started?

        start_time = Time.new.to_i
        while building?
          elapsed_time = Time.new.to_i - start_time
          yield elapsed_time, last_time_elapsed
          sleep(2)
        end

        success?
      end

      def exists?
        `curl -s -I #{ci_host}/` =~ /\b200 OK\b/
      end

      def console
        raw = `curl -s #{ci_host}/lastBuild/console`
        raw[%r{<pre.*?>(.+)</pre>}m, 1]
      end

      attr_accessor :last_response

      private

      def get_last_time_elapsed
        response = `curl -s #{ci_host}/lastStableBuild/api/xml`
        response.match(/<duration>(\d+)<\/duration>/)
        $1 ? $1.to_i / 1000 : nil
      end

      def auth
        "botandrose:11cc2ba6ef2e43fbfbedc1f466724f6290"
      end

      def ci_host
        "http://#{auth}@ci.botandrose.com/job/#{project_name}"
      end

      def start
        command = "curl -s -I -X POST -L '#{ci_host}/buildWithParameters?GIT_REF=#{sha}'"
        output = `#{command}`
        @queueId = output[%r{Location: .+/queue/item/(\d+)/}, 1].to_i
      end

      def started?
        command = "curl -s -g '#{ci_host}/api/json?depth=1&tree=builds[queueId,number]'"
        output = `#{command}`
        JSON.parse(output)["builds"][0]["queueId"] == @queueId
      end

      def job_id
        @job_id ||= begin
          output = `curl -s -g '#{ci_host}/api/json?depth=1&tree=builds[queueId,number]'`
          output[/"number":(\d+),"queueId":#{@queueId}\b/, 1].to_i
        end
      end

      def building?
        self.last_response = `curl -s #{ci_host}/#{job_id}/api/json?tree=building,result`
        if last_response.blank?
          sleep(2) # retry
          self.last_response = `curl -s #{ci_host}/#{job_id}/api/json?tree=building,result`
          if last_response.blank?
            raise "Blank response from CI twice in a row. Aborting!"
          end
        end
        last_response.include? '"building":true'
      end

      def success?
        last_response.include? '"result":"SUCCESS"'
      end
    end

    class Local < Struct.new(:project_name, :sha)
      def run
        start

        start_time = Time.new.to_i
        while building?
          elapsed_time = Time.new.to_i - start_time
          yield elapsed_time, nil
          sleep(2)
        end

        @stdin.close
        @console = @stdout_and_stderr.read
        @stdout_and_stderr.close

        success?
      end

      def exists?
        true
      end

      def console
        @console
      end

      attr_accessor :last_response

      private

      def start
        @stdin, @stdout_and_stderr, @wait_thread = Open3.popen2e("bin/rake ci")
      end

      def building?
        ![nil, false].include?(@wait_thread.status)
      end

      def success?
        @wait_thread.value.success?
      end
    end
  end
end

