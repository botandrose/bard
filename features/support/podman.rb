require "fileutils"
require "open3"
require "securerandom"
require "shellwords"
require "docker-api"

module PodmanWorld
  class << self
    attr_accessor :podman_available, :podman_image_built
  end

  class PrerequisiteError < StandardError; end

  def ensure_podman_available
    return if @podman_available || PodmanWorld.podman_available

    raise PrerequisiteError, "podman is not installed or not on PATH" unless system("command -v podman >/dev/null 2>&1")

    configure_podman_socket
    ensure_bard_test_image
    FileUtils.chmod(0o600, podman_ssh_key_path)

    PodmanWorld.podman_available = true
    @podman_available = true
  end

  def configure_podman_socket
    podman_socket = "/run/user/#{Process.uid}/podman/podman.sock"
    unless File.exist?(podman_socket)
      system("systemctl --user start podman.socket 2>/dev/null || podman system service --time=0 unix://#{podman_socket} &")
      sleep 2
    end

    raise PrerequisiteError, "Podman socket not available at #{podman_socket}" unless File.exist?(podman_socket)

    ENV["DOCKER_HOST"] = "unix://#{podman_socket}"
    Docker.url = ENV["DOCKER_HOST"]
  end

  def ensure_bard_test_image
    return if @podman_image_built || PodmanWorld.podman_image_built

    unless system("podman pull ubuntu:22.04 >/dev/null 2>&1")
      raise PrerequisiteError, "Unable to pull ubuntu:22.04 image"
    end

    docker_dir = File.join(ROOT, "spec/acceptance/docker")
    dockerfile = File.join(docker_dir, "Dockerfile")
    unless system("podman build -t bard-test-server -f #{dockerfile} #{docker_dir} 2>&1")
      raise PrerequisiteError, "Failed to build bard test image"
    end

    PodmanWorld.podman_image_built = true
    @podman_image_built = true
  end

  def start_podman_container
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

    ports = @podman_container.info["NetworkSettings"]["Ports"]["22/tcp"]
    @podman_ssh_port = ports.first["HostPort"].to_i

    wait_for_ssh
    run_ssh("mkdir -p testproject")
    write_bard_config
  end

  def wait_for_ssh
    30.times do
      return if run_ssh("echo ready", quiet: true)
      sleep 0.5
    end

    raise PrerequisiteError, "SSH in podman container did not become ready"
  end

  def write_bard_config
    FileUtils.mkdir_p(File.join(ROOT, "tmp"))
    @bard_config_path = File.join(ROOT, "tmp", "test_bard_#{SecureRandom.hex(4)}.rb")

    File.write(@bard_config_path, <<~RUBY)
      target :production do
        ssh "deploy@localhost:#{@podman_ssh_port}",
          path: "testproject",
          ssh_key: "#{podman_ssh_key_path}"
        ping false
      end
    RUBY
  end

  def run_ssh(command, quiet: false)
    ssh_args = [
      "ssh",
      "-o", "StrictHostKeyChecking=no",
      "-o", "UserKnownHostsFile=/dev/null",
      "-o", "LogLevel=ERROR",
      "-o", "ConnectTimeout=5",
      "-p", @podman_ssh_port.to_s,
      "-i", podman_ssh_key_path,
      "deploy@localhost",
      command
    ]

    if quiet
      system(*ssh_args, out: File::NULL, err: File::NULL)
    else
      system(*ssh_args)
    end
  end

  def run_bard_against_container(command)
    Dir.chdir(File.join(ROOT, "tmp")) do
      FileUtils.cp(@bard_config_path, "bard.rb")
      @stdout, @status = Open3.capture2e(@env || {}, "bard run #{command}")
      @stderr = ""
      FileUtils.rm_f("bard.rb")
    end
  end

  def podman_ssh_key_path
    @podman_ssh_key_path ||= File.expand_path(File.join(ROOT, "spec/acceptance/docker/test_key"))
  end

  def stop_podman_container
    FileUtils.rm_f(@bard_config_path) if @bard_config_path
    return unless @podman_container

    @podman_container.stop
    @podman_container.delete(force: true)
  rescue StandardError => e
    warn "Failed to cleanup podman container: #{e.message}"
  ensure
    @podman_container = nil
    @podman_ssh_port = nil
  end
end

World(PodmanWorld)

Before("@podman") do
  @env ||= {}

  begin
    start_podman_container
  rescue PodmanWorld::PrerequisiteError => e
    pending(e.message)
  end
end

After("@podman") do
  stop_podman_container
end
