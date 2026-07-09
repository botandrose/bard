require "uri"
require "bard/config"
require "bard/target"

class Bard::Config
  def github_pages(url = nil)
    hostname = if url
      uri = url.start_with?("http") ? URI.parse(url) : URI.parse("https://#{url}")
      uri.hostname.sub(/^www\./, "")
    elsif defined?(Bard::Git)
      Bard::Git.github_pages_url
    end

    remove_target :production
    target :production do
      github_pages url
      url hostname
    end

    backup(false) if respond_to?(:backup)
  end
end

class Bard::Target
  def github_pages(*args)
    if args.empty?
      @github_pages_url
    else
      @deploy_strategy = :github_pages
      @github_pages_url = args.first
      enable_capability(:github_pages)
    end
  end
end
