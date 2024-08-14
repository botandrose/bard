module Bard
  class Ping < Struct.new(:server)
    def self.call server
      new(server).call
    end

    def call
      return true if server.ping == false

      url = server.default_ping
      if server.ping =~ %r{^/}
        url += server.ping
      elsif server.ping.to_s.length > 0
        url = server.ping
      end

      command = "curl -sfL #{url} 2>&1 1>/dev/null"
      system command
    end
  end
end
