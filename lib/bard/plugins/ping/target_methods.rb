require "bard/target"
require "bard/plugins/url/target_methods"
require "bard/plugins/ping/check"

class Bard::Target
  def ping(*urls)
    if urls.empty?
      @ping_urls || [url].compact
    elsif urls.first == false
      @ping_urls = []
    else
      @ping_urls = urls.flatten.map { |u| normalize_url(u) }
    end
  end

  def ping!
    require_capability!(:url)
    failed_urls = Bard::Ping.call(self)
    if failed_urls.any?
      raise "Ping failed for: #{failed_urls.join(", ")}"
    end
  end
end
