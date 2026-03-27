require "fileutils"
require "open3"
require "tmpdir"
require "docker-api"

module ProvisionServerWorld
  class << self
    attr_accessor :server_available, :image_built
  end

  class PrerequisiteError < StandardError; end

  def ensure_provision_server_available
    return if ProvisionServerWorld.server_available

    unless system("command -v podman >/dev/null 2>&1")
      raise PrerequisiteError, "podman is not installed"
    end

    configure_provision_socket
    build_provision_image
    FileUtils.chmod(0o600, provision_ssh_key_path)

    ProvisionServerWorld.server_available = true
  end

  def configure_provision_socket
    if ENV["DOCKER_HOST"]
      Docker.url = ENV["DOCKER_HOST"]
      return
    end

    socket_path = "/run/user/#{Process.uid}/podman/podman.sock"
    unless File.exist?(socket_path)
      system("systemctl --user start podman.socket 2>/dev/null")
      sleep 2
    end

    unless File.exist?(socket_path)
      raise PrerequisiteError, "Podman socket not available"
    end

    ENV["DOCKER_HOST"] = "unix://#{socket_path}"
    Docker.url = ENV["DOCKER_HOST"]
  end

  def build_provision_image
    return if ProvisionServerWorld.image_built

    if provision_image_exists?("bard-test-provision")
      ProvisionServerWorld.image_built = true
      return
    end

    docker_dir = File.join(ROOT, "spec/acceptance/docker")
    unless system("podman build -t bard-test-provision -f #{docker_dir}/Dockerfile.provision #{docker_dir} 2>&1")
      raise PrerequisiteError, "Failed to build provision test image"
    end

    ProvisionServerWorld.image_built = true
  end

  def provision_image_exists?(name)
    Docker::Image.get(name)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def start_provision_server
    ensure_provision_server_available

    @container = Docker::Container.create(
      "Image" => "localhost/bard-test-provision:latest",
      "ExposedPorts" => { "22/tcp" => {}, "80/tcp" => {} },
      "HostConfig" => {
        "PortBindings" => {
          "22/tcp" => [{ "HostPort" => "" }],
          "80/tcp" => [{ "HostPort" => "" }],
        },
        "PublishAllPorts" => true,
        "Privileged" => true,
      }
    )
    @container.start
    @container.refresh!

    @ssh_port = @container.info["NetworkSettings"]["Ports"]["22/tcp"].first["HostPort"].to_i
    @http_port = @container.info["NetworkSettings"]["Ports"]["80/tcp"].first["HostPort"].to_i
    @container_ip = "127.0.0.1"

    wait_for_systemd
    setup_local_test_directory
  end

  def wait_for_systemd
    last_output = ""
    60.times do
      stdout, status = Open3.capture2e(
        "ssh", "-4", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
        "-o", "ConnectTimeout=2", "-p", @ssh_port.to_s, "-i", provision_ssh_key_path,
        "root@#{@container_ip}", "systemctl is-system-running 2>/dev/null || true"
      )
      last_output = stdout.strip.split("\n").last.to_s
      if last_output =~ /running|degraded/
        # Remove nologin so non-root users can SSH (systemd-user-sessions may not run in container)
        Open3.capture2e(
          "ssh", "-4", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
          "-p", @ssh_port.to_s, "-i", provision_ssh_key_path,
          "root@#{@container_ip}", "rm -f /run/nologin"
        )
        return
      end
      sleep 1
    end
    raise PrerequisiteError, "systemd not ready after 60s, last output: #{last_output}"
  end

  def setup_local_test_directory
    @test_parent = Dir.mktmpdir("bard_provision")
    @test_dir = File.join(@test_parent, "testproject")
    FileUtils.mkdir_p(@test_dir)

    Dir.chdir(@test_dir) do
      system("git init", out: File::NULL, err: File::NULL)
      system("git config user.email 'test@example.com'", out: File::NULL, err: File::NULL)
      system("git config user.name 'Test User'", out: File::NULL, err: File::NULL)

      File.write("bard.rb", <<~RUBY)
        target :production do
          ssh "www@#{@container_ip}:#{@ssh_port}",
            path: "testproject",
            ssh_key: "#{provision_ssh_key_path}"
          url "http://testproject.localhost"
          ping false
        end
      RUBY

      FileUtils.mkdir_p("config")
      File.write("config/master.key", "fake_master_key_for_testing")

      File.write(".ruby-version", "ruby-3.3.4")

      system("git add -A && git commit -m 'initial'", out: File::NULL, err: File::NULL)
    end
  end

  def setup_test_project
    # Copy bard source to container
    run_provision_ssh_as("root", "mkdir -p /home/www/bard-src && chown www:www /home/www/bard-src")

    bard_tar = File.join(@test_dir, "bard-src.tar.gz")
    system("tar czf #{bard_tar} -C #{ROOT} --exclude=.git --exclude=tmp --exclude=coverage .", out: File::NULL, err: File::NULL)

    system(
      "scp", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
      "-P", @ssh_port.to_s, "-i", provision_ssh_key_path,
      bard_tar, "www@#{@container_ip}:/home/www/bard-src/bard-src.tar.gz",
      out: File::NULL, err: File::NULL
    )
    run_provision_ssh_as("www", "cd /home/www/bard-src && tar xzf bard-src.tar.gz && rm bard-src.tar.gz")
    FileUtils.rm_f(bard_tar)

    # Create test project
    run_provision_ssh_as("www", <<~'SH')
      mkdir -p ~/testproject/bin ~/testproject/db ~/testproject/public ~/testproject/config ~/testproject/log
    SH

    run_provision_ssh_as("www", <<~SH)
      cat > ~/testproject/Gemfile << 'GEMFILE'
source "https://rubygems.org"
gem "bard", path: "/home/www/bard-src"
GEMFILE
    SH

    run_provision_ssh_as("www", <<~SH)
      cat > ~/testproject/bin/setup << 'SCRIPT'
#!/bin/bash
bundle install --quiet
SCRIPT
      chmod +x ~/testproject/bin/setup
    SH

    run_provision_ssh_as("www", <<~SH)
      cat > ~/testproject/bin/rake << 'SCRIPT'
#!/bin/bash
case "$1" in
  db:dump)
    echo "test data" | gzip > db/data.sql.gz
    ;;
  db:load)
    gunzip -c db/data.sql.gz > /dev/null
    echo "Data loaded"
    ;;
esac
SCRIPT
      chmod +x ~/testproject/bin/rake
    SH

    run_provision_ssh_as("www", <<~SH)
      cat > ~/testproject/bard.rb << 'BARDCONFIG'
target :production do
  ssh "www@#{@container_ip}:#{@ssh_port}",
    path: "testproject"
  url "http://testproject.localhost"
  ping false
end
BARDCONFIG
    SH

    run_provision_ssh_as("www", "echo 'ruby-3.3.4' > ~/testproject/.ruby-version")

    # Initialize git repo
    run_provision_ssh_as("www", <<~SH)
      cd ~/testproject && \
      git config --global user.email "test@example.com" && \
      git config --global user.name "Test User" && \
      git config --global init.defaultBranch master && \
      git init && git add -A && git commit -m "Initial commit"
    SH

    # Set up a bare remote so Repo step's on_latest_master? works (fetch origin)
    run_provision_ssh_as("www", <<~SH)
      git clone --bare ~/testproject ~/repos/testproject.git && \
      cd ~/testproject && git remote add origin ~/repos/testproject.git
    SH

    # Create a simple HTTP backend on port 3000 via systemd (survives SSH disconnect)
    run_provision_ssh_as("www", "echo 'hello from testproject' > ~/testproject/public/index.html")
    run_provision_ssh_as("root", <<~SH)
      cat > /etc/systemd/system/testproject-web.service << 'UNIT'
[Unit]
Description=Test project web server

[Service]
ExecStart=/usr/bin/python3 -m http.server 3000 -d /home/www/testproject/public
User=www

[Install]
WantedBy=multi-user.target
UNIT
      systemctl daemon-reload
      systemctl enable --now testproject-web
    SH
  end

  def run_provision_phase1
    Dir.chdir(@test_dir) do
      bard_coverage = File.join(ROOT, "features/support/bard-coverage")
      @stdout, @status = Open3.capture2e("#{bard_coverage} provision root@#{@container_ip}:#{@ssh_port} --steps=SSH User AuthorizedKeys Apt")
    end
  end

  def run_provision_phase2
    Dir.chdir(@test_dir) do
      bard_coverage = File.join(ROOT, "features/support/bard-coverage")
      @stdout, @status = Open3.capture2e("#{bard_coverage} provision www@#{@container_ip}:#{@ssh_port} --steps=Repo MasterKey RVM App Nginx Deploy HTTP LogRotation")
    end
  end

  def run_provision_ssh_as(user, command)
    stdout, status = Open3.capture2e(
      "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
      "-p", @ssh_port.to_s, "-i", provision_ssh_key_path,
      "#{user}@#{@container_ip}", command
    )
    unless status.success?
      raise PrerequisiteError, "SSH command failed (#{user}): #{command}\nOutput: #{stdout}"
    end
    stdout
  end

  def provision_ssh_key_path
    File.join(ROOT, "spec/acceptance/docker/test_key")
  end

  def stop_provision_server
    return unless @container
    @container.stop rescue nil
    @container.delete(force: true) rescue nil
  ensure
    @container = nil
    @ssh_port = nil
    FileUtils.rm_rf(@test_parent) if @test_parent
    @test_dir = nil
    @test_parent = nil
  end
end

World(ProvisionServerWorld)

Before("@provision") do
  start_provision_server
end

After("@provision") do
  stop_provision_server
end
