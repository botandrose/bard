require "uri"
require "bard/plugins/url"

class Bard::CLI
  desc "setup", "installs app in nginx"
  def setup
    path = "/etc/nginx/sites-available/#{project_name}"
    system "sudo tee #{path} >/dev/null <<-'EOF'
upstream puma {
    server 127.0.0.1:3000 fail_timeout=5;
}

server {
    listen 80;
    server_name #{nginx_server_name};
    root #{Dir.pwd}/public;

    try_files $uri @app;

    location @app {
        proxy_pass http://puma;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location ~* \\-[0-9a-f]\\{64\\}\\.(ico|css|js|gif|jpe?g|png|webp)$ {
        access_log off;
        expires max;
        add_header Cache-Control public;
    }

    gzip_static on;
}
EOF"

    dest_path = path.sub("sites-available", "sites-enabled")
    system "sudo ln -sf #{path} #{dest_path}" if !File.exist?(dest_path)

    system "sudo service nginx restart"
  end

  no_commands do
    def nginx_server_name
      case ENV["RAILS_ENV"]
      when "production"
        "*.#{URI.parse(config[:production].url).host} _"
      when "staging" then "#{project_name}.botandrose.com"
      else "#{project_name}.localhost"
      end
    end
  end
end
