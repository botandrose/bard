require "net/http"
require "json"
require "base64"
require "rbnacl"
require "bard/ci/retryable"

module Bard
  class Github < Struct.new(:project_name)
    include CI::Retryable

    def initialize(project_name, api_key: nil)
      super(project_name)
      @api_key = api_key
    end

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

    def put path, params={}
      request(path) do |uri|
        Net::HTTP::Put.new(uri).tap do |r|
          r.body = JSON.dump(params)
        end
      end
    end

    def patch path, params={}
      request(path) do |uri|
        Net::HTTP::Patch.new(uri).tap do |r|
          r.body = JSON.dump(params)
        end
      end
    end

    def delete path, params={}
      request(path) do |uri|
        Net::HTTP::Delete.new(uri).tap do |r|
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

    def add_master_key master_key
      response = get("actions/secrets/public-key")
      public_key, public_key_id = response.values_at("key", "key_id")

      def encrypt_secret(encoded_public_key, secret)
        decoded_key = Base64.decode64(encoded_public_key)
        public_key = RbNaCl::PublicKey.new(decoded_key)
        box = RbNaCl::Boxes::Sealed.from_public_key(public_key)
        encrypted_secret = box.encrypt(secret)
        Base64.strict_encode64(encrypted_secret)
      end

      encrypted_master_key = encrypt_secret(public_key, master_key)

      put("actions/secrets/RAILS_MASTER_KEY", {
        encrypted_value: encrypted_master_key,
        key_id: public_key_id,
      })
    end

    def add_master_branch_protection
      put("branches/master/protection", {
        required_status_checks: {
          strict: false,
          contexts: [],
        },
        enforce_admins: nil,
        required_pull_request_reviews: nil,
        restrictions: nil,
      })
    end

    def create_repo
      post("https://api.github.com/orgs/botandrosedesign/repos", {
        name: project_name,
        private: true,
      })
    end

    def delete_repo
      delete(nil)
    end

    private

    def api_key
      @api_key ||= begin
        raw = `git ls-remote -t git@github.com:botandrosedesign/secrets`
        raw[/github-apikey\|(.+)$/, 1]
      end
    end

    def request path, &block
      uri = if path =~ /^http/
        URI(path)
      else
        base = "https://api.github.com/repos/botandrosedesign/#{project_name}"
        if path
          URI(File.join(base, path))
        else
          URI(base)
        end
      end

      retry_with_backoff do
        req = nil
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          req = block.call(uri)
          req["Accept"] = "application/vnd.github+json"
          req["Authorization"] = "Bearer #{api_key}"
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
          raise [req.method, req.uri, req.to_hash, response, response.body].inspect
        end
      end
    end
  end
end

