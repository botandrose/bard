require "net/http"
require "json"
require "base64"

module Bard
  class Github < Struct.new(:project_name)
    def get path, params={}
      request(path) do |uri|
        uri.query = URI.encode_www_form(params)
        Net::HTTP::Get.new(uri)
      end
    end

    def post path, params={}
      request(path) do |uri|
        Net::HTTP::Post.new(uri).tap do |r|
          r.body = JSON.dump(params)
        end
      end
    end

    def read_file path, branch: "master"
      metadata = get("contents/#{path}", ref: branch)
      Base64.decode64(metadata["content"])
    end

    def add_deploy_key title:, key:
      post("keys", title:, key:)
    end

    private

    def github_apikey
      @github_apikey ||= begin
        raw = `git ls-remote -t git@github.com:botandrose/bard`
        raw[/github-apikey\|(.+)$/, 1]
      end
    end

    def request path, &block
      uri = if path =~ /^http/
        URI(path)
      else
        URI("https://api.github.com/repos/botandrosedesign/#{project_name}/#{path}")
      end

      req = nil
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        req = block.call(uri)
        req["Accept"] = "application/vnd.github+json"
        req["Authorization"] = "Bearer #{github_apikey}"
        req["X-GitHub-Api-Version"] = "2022-11-28"
        http.request(req)
      end

      case response
      when Net::HTTPRedirection then
        Net::HTTP.get(URI(response["Location"]))
      when Net::HTTPSuccess then
        if response["Content-Type"].to_s.include?("/json")
          JSON.load(response.body)
        else
          response.body
        end
      else
        raise [req.method, req.uri, req.to_hash, response].inspect
      end
    end
  end
end

