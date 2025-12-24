require "fileutils"
require "open3"
require "docker-api"

module PodmanWorld
  class << self
    attr_accessor :podman_available, :podman_image_built
  end

  class PrerequisiteError < StandardError; end

  def ensure_podman_available
    return if PodmanWorld.podman_available

    unless system("command -v podman >/dev/null 2>&1")
      raise PrerequisiteError, "podman is not installed"
    end

    configure_podman_socket
    build_test_image
    FileUtils.chmod(0o600, ssh_key_path)

    PodmanWorld.podman_available = true
  end

  def configure_podman_socket
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
    return if PodmanWorld.podman_image_built

    # Check if image already exists (e.g., pre-built in CI)
    if image_exists?("bard-test-server")
      PodmanWorld.podman_image_built = true
      return
    end

    system("podman pull ubuntu:22.04 >/dev/null 2>&1")

    docker_dir = File.join(ROOT, "spec/acceptance/docker")
    unless system("podman build -t bard-test-server -f #{docker_dir}/Dockerfile #{docker_dir} 2>&1")
      raise PrerequisiteError, "Failed to build test image"
    end

    PodmanWorld.podman_image_built = true
  end

  def image_exists?(name)
    Docker::Image.get(name)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def start_test_server
    ensure_podman_available

    @podman_container = Docker::Container.create(
      "Image" => "localhost/bard-test-server:latest",
      "ExposedPorts" => { "22/tcp" => {} },
      "HostConfig" => {
        "PortBindings" => { "22/tcp" => [{ "HostPort" => "" }] },
        "PublishAllPorts" => true
      }
    )
    @podman_container.start
    @podman_container.refresh!

    @podman_ssh_port = @podman_container.info["NetworkSettings"]["Ports"]["22/tcp"].first["HostPort"].to_i

    wait_for_ssh
    setup_test_directory
    write_bard_config
  end

  def wait_for_ssh
    30.times do
      return if system(
        "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
        "-o", "ConnectTimeout=1", "-p", @podman_ssh_port.to_s, "-i", ssh_key_path,
        "deploy@localhost", "true",
        out: File::NULL, err: File::NULL
      )
      sleep 0.5
    end
    raise PrerequisiteError, "SSH not ready"
  end

  def setup_test_directory
    system(
      "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
      "-p", @podman_ssh_port.to_s, "-i", ssh_key_path,
      "deploy@localhost", "mkdir -p testproject",
      out: File::NULL, err: File::NULL
    )
  end

  def write_bard_config
    FileUtils.mkdir_p(File.join(ROOT, "tmp"))
    @bard_config_path = File.join(ROOT, "tmp", "bard.rb")

    File.write(@bard_config_path, <<~RUBY)
      target :production do
        ssh "deploy@localhost:#{@podman_ssh_port}",
          path: "testproject",
          ssh_key: "#{ssh_key_path}"
        ping false
      end
    RUBY
  end

  def run_bard(command)
    Dir.chdir(File.join(ROOT, "tmp")) do
      @stdout, @status = Open3.capture2e("bard #{command}")
    end
  end

  def ssh_key_path
    File.join(ROOT, "spec/acceptance/docker/test_key")
  end

  def stop_test_server
    return unless @podman_container
    @podman_container.stop rescue nil
    @podman_container.delete(force: true) rescue nil
  ensure
    @podman_container = nil
    @podman_ssh_port = nil
    FileUtils.rm_f(@bard_config_path) if @bard_config_path
  end
end

World(PodmanWorld)

Before do
  start_test_server
end

After do
  stop_test_server
end
