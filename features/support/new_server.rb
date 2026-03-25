require "fileutils"
require "open3"
require "docker-api"

module NewServerWorld
  class << self
    attr_accessor :server_available, :image_built
  end

  class PrerequisiteError < StandardError; end

  def ensure_new_server_available
    return if NewServerWorld.server_available

    unless system("command -v podman >/dev/null 2>&1")
      raise PrerequisiteError, "podman is not installed"
    end

    configure_new_container_socket
    build_new_test_image
    FileUtils.chmod(0o600, new_ssh_key_path)

    NewServerWorld.server_available = true
  end

  def configure_new_container_socket
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

  def build_new_test_image
    return if NewServerWorld.image_built

    if new_image_exists?("bard-test-new")
      NewServerWorld.image_built = true
      return
    end

    dockerfile = File.join(ROOT, "spec/acceptance/docker/Dockerfile.new")
    unless system("podman build -t bard-test-new -f #{dockerfile} #{ROOT} 2>&1")
      raise PrerequisiteError, "Failed to build bard-test-new image"
    end

    NewServerWorld.image_built = true
  end

  def new_image_exists?(name)
    Docker::Image.get(name)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def start_new_server
    ensure_new_server_available

    @new_container = Docker::Container.create(
      "Image" => "localhost/bard-test-new:latest",
      "ExposedPorts" => { "22/tcp" => {} },
      "HostConfig" => {
        "PortBindings" => { "22/tcp" => [{ "HostPort" => "" }] },
        "PublishAllPorts" => true
      }
    )
    @new_container.start
    @new_container.refresh!

    @new_ssh_port = @new_container.info["NetworkSettings"]["Ports"]["22/tcp"].first["HostPort"].to_i

    wait_for_new_ssh
  end

  def wait_for_new_ssh
    30.times do
      return if system(
        "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
        "-o", "ConnectTimeout=1", "-p", @new_ssh_port.to_s, "-i", new_ssh_key_path,
        "deploy@localhost", "true",
        out: File::NULL, err: File::NULL
      )
      sleep 0.5
    end
    raise PrerequisiteError, "SSH not ready"
  end

  def run_new_ssh(command)
    escaped = command.gsub("'", "'\"'\"'")
    Open3.capture2e(
      "ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
      "-p", @new_ssh_port.to_s, "-i", new_ssh_key_path,
      "deploy@localhost", "bash -lc '#{escaped}'"
    )
  end

  def run_bard_remote(command)
    @stdout, @status = run_new_ssh("mkdir -p /tmp/bardwork/current && cd /tmp/bardwork/current && bard #{command}")
  end

  def new_ssh_key_path
    File.join(ROOT, "spec/acceptance/docker/test_key")
  end

  def stop_new_server
    return unless @new_container
    @new_container.stop rescue nil
    @new_container.delete(force: true) rescue nil
  ensure
    @new_container = nil
    @new_ssh_port = nil
  end
end

World(NewServerWorld)

Before("@new") do
  start_new_server
end

After("@new") do
  stop_new_server
end
