module AptDependencies
  def self.ensure!
    deps = File.readlines("Aptfile", chomp: true)
    deps.map do |dep|
      "apt list #{dep} | grep '\\[installed\\]' || sudo apt install -y #{dep}"
    end.join(" && ")
  rescue Errno::ENOENT
    "true"
  end
end
