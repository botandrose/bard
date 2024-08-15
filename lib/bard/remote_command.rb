module Bard
  class RemoteCommand < Struct.new(:server, :command, :home)
    def local_command
      uri = URI.parse("ssh://#{server.ssh}")
      ssh_key = server.ssh_key ? "-i #{server.ssh_key} " : ""
      cmd = command
      if server.env
        cmd = "#{server.env} #{command}"
      end
      unless home
        cmd = "cd #{server.path} && #{cmd}"
      end
      cmd = "ssh -tt #{ssh_key}#{"-p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} '#{cmd}'"
      if server.gateway
        uri = URI.parse("ssh://#{server.gateway}")
        cmd = "ssh -tt #{" -p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} \"#{cmd}\""
      end
      cmd
    end
  end
end

