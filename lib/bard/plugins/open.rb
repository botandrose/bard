class Bard::CLI
  desc "open [server=production]", "opens the url in the web browser."
  def open(server = :production)
    exec "xdg-open #{open_url server}"
  end

  no_commands do
    def open_url(server)
      if server.to_sym == :ci
        "https://github.com/botandrosedesign/#{project_name}/actions/workflows/ci.yml"
      else
        config[server].url
      end
    end
  end
end
