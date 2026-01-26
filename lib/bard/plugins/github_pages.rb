require "bard/plugin"

# Load the deploy strategy (auto-registers via inherited hook)
require "bard/deploy_strategy/github_pages"

Bard::Plugin.register :github_pages do
  # Config DSL: github_pages "url" sets up a production target
  config_method :github_pages do |url|
    urls = []
    uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
    hostname = uri.hostname.sub(/^www\./, "")
    urls = [hostname]
    urls << "www.#{hostname}" if hostname.count(".") < 2

    target :production do
      github_pages url
      ssh false
      ping(*urls) if urls.any?
    end

    backup false
  end

  # Target DSL: github_pages sets deploy strategy
  target_method :github_pages do |url = nil|
    if url.nil?
      @github_pages_url
    else
      @deploy_strategy = :github_pages
      @github_pages_url = url
      enable_capability(:github_pages)
    end
  end
end
