class Bard::CLI
  desc "open [target=production]", "opens the url in the web browser."
  def open(target = :production)
    exec "xdg-open #{open_url target}"
  end

  no_commands do
    def open_url(target)
      if target.to_sym == :ci
        "https://github.com/botandrosedesign/#{project_name}/actions/workflows/ci.yml"
      else
        t = config[target]
        t.require_capability!(:url)
        t.url
      end
    end
  end
end
