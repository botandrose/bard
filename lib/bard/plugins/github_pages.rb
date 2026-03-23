require "bard/plugins/github_pages/strategy"
require "bard/config"
require "bard/target"

class Bard::Config
  def github_pages(url)
    uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
    hostname = uri.hostname.sub(/^www\./, "")

    target :production do
      github_pages url
      ssh false
      url(hostname) if hostname
    end

    backup(false) if respond_to?(:backup)
  end
end

class Bard::Target
  def github_pages(url = nil)
    if url.nil?
      @github_pages_url
    else
      @deploy_strategy = :github_pages
      @github_pages_url = url
      enable_capability(:github_pages)
    end
  end
end
