require "bard/plugin"

Bard::Plugin.register :jenkins do
  # Jenkins CI runner - auto-registers via inherited hook when loaded
  require_file "bard/ci/jenkins"
end
