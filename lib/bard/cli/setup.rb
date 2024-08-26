require "uri"

module Bard::CLI::Setup
  def self.included mod
    mod.class_eval do

      desc "setup", "installs app in nginx"
      def setup
        system "sudo tee /etc/nginx/snippets/common.conf >/dev/null <<-EOF
listen 80;

passenger_enabled on;

location ~* \\.(ico|css|js|gif|jp?g|png|webp) {
    access_log off;
    if (\\$request_filename ~ \"-[0-9a-f]{32}\\.\") {
        expires max;
        add_header Cache-Control public;
    }
}

gzip_static on;
EOF"

        path = "/etc/nginx/sites-available/#{project_name}"
        system "sudo tee #{path} >/dev/null <<-EOF
server {
    include /etc/nginx/snippets/common.conf;
    server_name #{nginx_server_name};
    root #{Dir.pwd}/public;
}
EOF"

        dest_path = path.sub("sites-available", "sites-enabled")
        system "sudo ln -sf #{path} #{dest_path}" if !File.exist?(dest_path)

        system "sudo service nginx restart"
      end

      private 

      def nginx_server_name
        case ENV["RAILS_ENV"]
        when "production"
          (config[:production].ping.map do |str|
            "*.#{URI.parse(str).host}"
          end + ["_"]).join(" ")
        when "staging" then "#{project_name}.botandrose.com"
        else "#{project_name}.localhost"
        end
      end

    end
  end
end

