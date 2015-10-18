class Bard::CLI < Thor
  class CI < Struct.new(:project_name, :current_sha)
    def run
      last_build_number = get_last_build_number
      last_time_elapsed = get_last_time_elapsed
      start
      sleep(2) while last_build_number == get_last_build_number

      start_time = Time.new.to_i
      while (self.last_response = `curl -s #{ci_host}/lastBuild/api/xml?token=botandrose`).include? "<building>true</building>"
        elapsed_time = Time.new.to_i - start_time
        yield elapsed_time, last_time_elapsed
        sleep(2)
      end

      self.last_response =~ /<result>SUCCESS<\/result>/
    end

    def exists?
      `curl -s -I #{ci_host}/?token=botandrose` =~ /\b200 OK\b/
    end

    def console
      raw = `curl -s #{ci_host}/lastBuild/console?token=botandrose`
      raw[%r{<pre.*?>(.+)</pre>}m, 1]
    end

    attr_accessor :last_response

    private

    def ci_host
      "http://botandrose:thecakeisalie!@ci.botandrose.com/job/#{project_name}"
    end

    def start
      `curl -s -I -X POST '#{ci_host}/buildWithParameters?token=botandrose&GIT_REF=#{current_sha}'`
    end

    def get_last_build_number
      response = `curl -s #{ci_host}/lastBuild/api/xml?token=botandrose`
      response.match(/<number>(\d+)<\/number>/)
      $1 ? $1.to_i : nil
    end

    def get_last_time_elapsed
      response = `curl -s #{ci_host}/lastStableBuild/api/xml?token=botandrose`
      response.match(/<duration>(\d+)<\/duration>/)
      $1 ? $1.to_i / 1000 : nil
    end
  end
end

