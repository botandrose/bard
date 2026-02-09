module Bard
  module Secrets
    REPO = "git@github.com:botandrosedesign/secrets"

    def self.fetch(key)
      raw = `git ls-remote -t #{REPO}`
      raw[/#{Regexp.escape(key)}\|(.+)$/, 1]
    end
  end
end
