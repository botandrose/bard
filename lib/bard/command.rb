module Bard
  class Command < Struct.new(:command, :on, :home)
    def self.run! command, on: :local, home: false, verbose: false
      new(command, on, home).run! verbose: verbose
    end

    def self.exec! command, on: :local, home: false
      new(command, on, home).exec!
    end

    def run! verbose: false
      failed = false

      if verbose
        failed = !(system full_command)
      else
        stdout, stderr, status = Open3.capture3(full_command)
        failed = status.to_i.nonzero?
        if failed
          $stdout.puts stdout
          $stderr.puts stderr
        end
      end

      if failed
        raise "Running command failed: #{full_command}"
      end
    end

    def exec!
      exec full_command
    end

    private

    def full_command
      if on.to_sym == :local
        command
      else
        remote_command
      end
    end

    def remote_command
      uri = URI.parse("ssh://#{on.ssh}")
      ssh_key = on.ssh_key ? "-i #{on.ssh_key} " : ""
      cmd = command
      if on.env
        cmd = "#{on.env} #{command}"
      end
      unless home
        cmd = "cd #{on.path} && #{cmd}"
      end
      cmd = "ssh -tt #{ssh_key}#{"-p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} '#{cmd}'"
      if on.gateway
        uri = URI.parse("ssh://#{on.gateway}")
        cmd = "ssh -tt #{" -p#{uri.port} " if uri.port}#{uri.user}@#{uri.host} \"#{cmd}\""
      end
      cmd
    end
  end
end
