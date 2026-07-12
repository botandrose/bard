require "uri"
require "bard/target"
require "bard/plugins/url/target_methods"
require "bard/plugins/ping/target_methods"

class Bard::Target
  # The public /bard/deploy endpoint URL for this target, or nil if it has no web address.
  # Prefers the health-checked ping host over the ssh-derived url, which for a proxied app can be
  # an origin with a non-public cert. Anchors to the host root so a ping path (e.g. "/up") is
  # dropped. Mirrors how `bard deploy` chooses where to POST.
  def deploy_url
    base = ping.first || url
    return unless base
    URI.join(base, "/bard/deploy").to_s
  end
end
