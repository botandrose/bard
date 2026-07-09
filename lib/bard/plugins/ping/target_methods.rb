require "bard/target"
require "bard/plugins/url/target_methods"

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
end
