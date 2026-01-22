require "fileutils"
require "open3"
require "tmpdir"
require "docker-api"

module TestServerWorld
  class << self
    attr_accessor :server_available, :image_built
  end

  class PrerequisiteError < StandardError; end

  def ensure_server_available
    return if TestServerWorld.server_available

    unless system("command -v podman >/dev/null 2>&1")
      raise PrerequisiteError, "podman is not installed"
    end

    configure_container_socket
    build_test_image
    FileUtils.chmod(0o600, ssh_key_path)

    TestServerWorld.server_available = true
  end

  def configure_container_socket
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

  def build_test_image
    return if TestServerWorld.image_built

    # Check if image already exists (e.g., pre-built in CI)
    if image_exists?("bard-test-server")
      TestServerWorld.image_built = true
      return
    end

    system("podman pull ubuntu:22.04 >/dev/null 2>&1")

    docker_dir = File.join(ROOT, "spec/acceptance/docker")
    unless system("podman build -t bard-test-server -f #{docker_dir}/Dockerfile #{docker_dir} 2>&1")
      raise PrerequisiteError, "Failed to build test image"
    end

    TestServerWorld.image_built = true
  end

  def image_exists?(name)
    Docker::Image.get(name)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def start_test_server
    ensure_server_available

    @container = Docker::Container.create(
      "Image" => "localhost/bard-test-server:latest",
      "ExposedPorts" => { "22/tcp" => {} },
      "HostConfig" => {
        "PortBindings" => { "22/tcp" => [{ "HostPort" => "" }] },
        "PublishAllPorts" => true
      }
    )
    @container.start
    @container.refresh!

    @ssh_port = @container.info["NetworkSettings"]["Ports"]["22/tcp"].first["HostPort"].to_i

    wait_for_ssh
    setup_test_directory
  end

  def wait_for_ssh
    30.times do
      return if system(
        "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
        "-o", "ConnectTimeout=1", "-p", @ssh_port.to_s, "-i", ssh_key_path,
        "deploy@localhost", "true",
        out: File::NULL, err: File::NULL
      )
      sleep 0.5
    end
    raise PrerequisiteError, "SSH not ready"
  end

  def setup_test_directory
    # Set up git repos on the remote container
    run_ssh "git config --global user.email 'test@example.com'"
    run_ssh "git config --global user.name 'Test User'"
    run_ssh "git config --global init.defaultBranch master"
    run_ssh "mkdir -p ~/repos/testproject.git"
    run_ssh "cd ~/repos/testproject.git && git init --bare"
    run_ssh "git clone ~/repos/testproject.git ~/testproject"
    run_ssh "mkdir -p ~/testproject/bin ~/testproject/db"

    # bin/setup script
    run_ssh "echo '#!/bin/bash' > ~/testproject/bin/setup"
    run_ssh "echo 'echo Setup complete' >> ~/testproject/bin/setup"
    run_ssh "chmod +x ~/testproject/bin/setup"

    # bin/rake script for db:dump and db:load
    run_ssh <<~'SETUP'
      cat > ~/testproject/bin/rake << 'SCRIPT'
#!/bin/bash
case "$1" in
  db:dump)
    echo "production data" | gzip > db/data.sql.gz
    ;;
  db:load)
    gunzip -c db/data.sql.gz > /dev/null
    echo "Data loaded"
    ;;
esac
SCRIPT
    SETUP
    run_ssh "chmod +x ~/testproject/bin/rake"
    run_ssh "cd ~/testproject && git add . && git commit -m 'Initial commit'"
    run_ssh "cd ~/testproject && git push origin master"

    # Set up local git repo in isolated temp directory
    setup_local_git_repo
  end

  def setup_local_git_repo
    @test_dir = Dir.mktmpdir("bard_test")
    @ssh_command = "ssh -i #{ssh_key_path} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

    Dir.chdir(@test_dir) do
      # Clone directly into the temp directory (pass SSH command via env, not global ENV)
      ssh_url = "ssh://deploy@localhost:#{@ssh_port}/home/deploy/repos/testproject.git"
      system({ "GIT_SSH_COMMAND" => @ssh_command }, "git clone #{ssh_url} .", out: File::NULL, err: File::NULL)

      # Configure git settings locally in this repo only
      system("git config user.email 'test@example.com'", out: File::NULL, err: File::NULL)
      system("git config user.name 'Test User'", out: File::NULL, err: File::NULL)
      system("git config core.sshCommand '#{@ssh_command}'", out: File::NULL, err: File::NULL)

      # Ensure db directory exists locally
      FileUtils.mkdir_p("db")

      # Write bard config in the test directory
      File.write("bard.rb", <<~RUBY)
        target :production do
          ssh "deploy@localhost:#{@ssh_port}",
            path: "testproject",
            ssh_key: "#{ssh_key_path}"
          ping false
        end
      RUBY
    end
  end

  def run_ssh(command)
    stdout, status = Open3.capture2e(
      "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
      "-p", @ssh_port.to_s, "-i", ssh_key_path,
      "deploy@localhost", command
    )
    unless status.success?
      raise PrerequisiteError, "SSH command failed: #{command}\nOutput: #{stdout}"
    end
    true
  end

  def run_bard(command)
    Dir.chdir(@test_dir) do
      bard_coverage = File.join(ROOT, "features/support/bard-coverage")
      @stdout, @status = Open3.capture2e("#{bard_coverage} #{command}")
    end
  end

  def ssh_key_path
    File.join(ROOT, "spec/acceptance/docker/test_key")
  end

  def stop_test_server
    return unless @container
    @container.stop rescue nil
    @container.delete(force: true) rescue nil
  ensure
    @container = nil
    @ssh_port = nil
    FileUtils.rm_rf(@test_dir) if @test_dir
    @test_dir = nil
  end
end

World(TestServerWorld)

Before do
  start_test_server
end

After do
  stop_test_server
end
