require "bard/target"

class Bard::Target
  def url(value = nil)
    if value.nil?
      @url
    elsif value == false
      @url = nil
      @capabilities.delete(:url)
    else
      @url = normalize_url(value)
      enable_capability(:url)
    end
  end

  private

  def normalize_url(value)
    normalized = value.to_s
    normalized = "https://#{normalized}" unless normalized.start_with?("http")
    normalized
  end
end
