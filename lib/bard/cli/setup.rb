require "uri"

module Bard::CLI::Setup
  def self.included mod
    mod.class_eval do

      desc "setup", "installs app in nginx"
      def setup
        path = "/etc/nginx/sites-available/#{project_name}"
        dest_path = path.sub("sites-available", "sites-enabled")
        server_name = case ENV["RAILS_ENV"]
        when "production"
          (config[:production].ping.map do |str|
            "*.#{URI.parse(str).host}"
          end + ["_"]).join(" ")
        when "staging" then "#{project_name}.botandrose.com"
        else "#{project_name}.localhost"
        end

        system "sudo tee #{path} >/dev/null <<-EOF
server {
  listen 80;
  server_name #{server_name};

  root #{Dir.pwd}/public;
  passenger_enabled on;

  location ~* \\.(ico|css|js|gif|jp?g|png|webp) {
    access_log off;
    if (\\$request_filename ~ \"-[0-9a-f]{32}\\.\") {
      expires max;
      add_header Cache-Control public;
    }
  }
  gzip_static on;
}
EOF"
        system "sudo ln -sf #{path} #{dest_path}" if !File.exist?(dest_path)
        system "sudo service nginx restart"
      end

    end
  end
end

