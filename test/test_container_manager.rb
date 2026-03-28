# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestContainerManager < Minitest::Test
  VALID_CONFIG = File.expand_path("fixtures/valid_config.yml", __dir__)

  def setup
    @config = Dockaroo::Config.load(VALID_CONFIG)
    @tmpdir = Dir.mktmpdir
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    @env_builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    @manager = Dockaroo::ContainerManager.new(config: @config, env_builder: @env_builder)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_run_command_replicated_service
    grabber = @config.find_service("grabber")
    cmd = @manager.run_command(service: grabber, host_name: "grabber02", replica: 2)

    assert cmd.start_with?("cd ~/booko-services && docker run")
    assert_includes cmd, "--name booko-grabber-2"
    assert_includes cmd, "--network host"
    assert_includes cmd, "--restart on-failure"
    assert_includes cmd, "--env MALLOC_ARENA_MAX=2"
    assert_includes cmd, "--env DOCKAROO_PROJECT=booko"
    assert_includes cmd, "--env DOCKAROO_SERVICE=grabber"
    assert_includes cmd, "--env DOCKAROO_HOST=grabber02"
    assert_includes cmd, "--env DOCKAROO_INSTANCE=2"
    assert_includes cmd, "--volume ./log:/rails/log"
    assert_includes cmd, "--log-driver json-file"
    assert_includes cmd, "--log-opt max-size=50m"
    assert_includes cmd, "--log-opt max-file=5"
    assert_includes cmd, "git.booko.info/booko/booko:latest"
    assert_includes cmd, "bundle exec bin/booko -W"
  end

  def test_run_command_single_replica_service
    scheduler = @config.find_service("scheduler")
    cmd = @manager.run_command(service: scheduler, host_name: "grabber02")

    assert_includes cmd, "--name booko-scheduler"
    refute_includes cmd, "DOCKAROO_INSTANCE"
  end

  def test_run_command_with_tag
    grabber = @config.find_service("grabber")
    cmd = @manager.run_command(service: grabber, host_name: "grabber01", replica: 1, tag: "abc123")

    assert_includes cmd, "git.booko.info/booko/booko:abc123"
  end

  def test_run_command_with_env_file
    grabber = @config.find_service("grabber")
    cmd = @manager.run_command(service: grabber, host_name: "grabber01", replica: 1, env_file_path: "/home/deploy/.dockaroo/env")

    assert_includes cmd, "--env-file /home/deploy/.dockaroo/env"
  end

  def test_run_command_without_env_file
    grabber = @config.find_service("grabber")
    cmd = @manager.run_command(service: grabber, host_name: "grabber01", replica: 1)

    refute_includes cmd, "--env-file"
  end

  def test_run_command_no_logging
    raw = {
      "project" => "test",
      "defaults" => { "image" => "registry.example.com/myapp:latest" },
      "hosts" => { "host1" => nil },
      "services" => { "worker" => { "cmd" => "ruby worker.rb", "hosts" => ["host1"] } }
    }
    config = Dockaroo::Config.new(raw: raw)
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: secrets)
    manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)

    worker = config.find_service("worker")
    cmd = manager.run_command(service: worker, host_name: "host1")

    refute_includes cmd, "--log-driver"
    refute_includes cmd, "--log-opt"
  end

  def test_run_command_no_network
    raw = {
      "project" => "test",
      "defaults" => { "image" => "registry.example.com/myapp:latest" },
      "hosts" => { "host1" => nil },
      "services" => { "worker" => { "cmd" => "ruby worker.rb", "hosts" => ["host1"] } }
    }
    config = Dockaroo::Config.new(raw: raw)
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: secrets)
    manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)

    worker = config.find_service("worker")
    cmd = manager.run_command(service: worker, host_name: "host1")

    refute_includes cmd, "--network"
  end

  def test_run_command_with_ports
    raw = {
      "project" => "test",
      "hosts" => { "host1" => nil },
      "services" => {
        "caddy" => {
          "image" => "caddy:2-alpine",
          "hosts" => ["host1"],
          "ports" => ["80:80", "443:443"]
        }
      }
    }
    config = Dockaroo::Config.new(raw: raw)
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: secrets)
    manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)

    caddy = config.find_service("caddy")
    cmd = manager.run_command(service: caddy, host_name: "host1")

    assert_includes cmd, "--publish 80:80"
    assert_includes cmd, "--publish 443:443"
    assert_includes cmd, "caddy:2-alpine"
  end

  def test_run_command_without_cmd
    raw = {
      "project" => "test",
      "hosts" => { "host1" => nil },
      "services" => {
        "caddy" => {
          "image" => "caddy:2-alpine",
          "hosts" => ["host1"]
        }
      }
    }
    config = Dockaroo::Config.new(raw: raw)
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: secrets)
    manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)

    caddy = config.find_service("caddy")
    cmd = manager.run_command(service: caddy, host_name: "host1")

    assert_includes cmd, "caddy:2-alpine"
    # Command should end with the image, not a nil
    refute_includes cmd, "nil"
  end

  def test_run_command_default_remote_dir
    raw = {
      "project" => "test",
      "defaults" => { "image" => "registry.example.com/myapp:latest" },
      "hosts" => { "host1" => nil },
      "services" => { "worker" => { "cmd" => "ruby worker.rb", "hosts" => ["host1"] } }
    }
    config = Dockaroo::Config.new(raw: raw)
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: secrets)
    manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)

    worker = config.find_service("worker")
    cmd = manager.run_command(service: worker, host_name: "host1")

    assert cmd.start_with?("cd ~ && docker run")
  end

  def test_run_command_custom_remote_dir
    raw = {
      "project" => "test",
      "defaults" => { "image" => "registry.example.com/myapp:latest", "remote_dir" => "~/my-services" },
      "hosts" => { "host1" => nil },
      "services" => { "worker" => { "cmd" => "ruby worker.rb", "hosts" => ["host1"] } }
    }
    config = Dockaroo::Config.new(raw: raw)
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: secrets)
    manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)

    worker = config.find_service("worker")
    cmd = manager.run_command(service: worker, host_name: "host1")

    assert cmd.start_with?("cd ~/my-services && docker run")
  end

  def test_run_command_no_image_raises
    service = Dockaroo::Config::Service.new(name: "broken", cmd: "echo hi", hosts: ["host1"])
    assert_raises(Dockaroo::ConfigError) do
      @manager.run_command(service: service, host_name: "host1")
    end
  end

  def test_stop_command
    grabber = @config.find_service("grabber")
    host = @config.find_host("grabber01")

    commands_run = []
    fake_executor = Object.new
    fake_executor.define_singleton_method(:run) { |cmd| commands_run << cmd; Dockaroo::SSHResult.new(stdout: "", stderr: "", exit_status: 0) }

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      @manager.stop(service: grabber, host: host, replica: 1)
    end

    assert_equal 1, commands_run.size
    assert_includes commands_run.first, "docker stop --time 10 booko-grabber-1"
  end

  def test_remove_command
    grabber = @config.find_service("grabber")
    host = @config.find_host("grabber01")

    commands_run = []
    fake_executor = Object.new
    fake_executor.define_singleton_method(:run) { |cmd| commands_run << cmd; Dockaroo::SSHResult.new(stdout: "", stderr: "", exit_status: 0) }

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      @manager.remove(service: grabber, host: host, replica: 1)
    end

    assert_equal 1, commands_run.size
    assert_includes commands_run.first, "docker rm booko-grabber-1"
  end

  def test_status_empty_output
    host = @config.find_host("grabber01")
    fake_executor = Object.new
    fake_executor.define_singleton_method(:run) { |_cmd| Dockaroo::SSHResult.new(stdout: "", stderr: "", exit_status: 0) }

    containers = nil
    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      containers = @manager.status(host: host)
    end

    assert_equal [], containers
  end
end

# Tests using real docker ps output from grabber02
class TestContainerManagerRealData < Minitest::Test
  VALID_CONFIG = File.expand_path("fixtures/valid_config.yml", __dir__)
  DOCKER_PS_FIXTURE = File.expand_path("fixtures/docker_ps_grabber02.json", __dir__)

  def setup
    @config = Dockaroo::Config.load(VALID_CONFIG)
    @tmpdir = Dir.mktmpdir
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    env_builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    @manager = Dockaroo::ContainerManager.new(config: @config, env_builder: env_builder)
    @fixture_data = File.read(DOCKER_PS_FIXTURE)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def parsed_containers
    @manager.send(:parse_docker_ps, @fixture_data)
  end

  def test_parses_all_containers
    containers = parsed_containers
    assert_equal 17, containers.size
  end

  def test_parses_compose_managed_containers
    containers = parsed_containers
    scheduler = containers.find { |c| c[:name] == "booko-scheduler-1" }

    assert_equal "scheduler", scheduler[:service]
    assert_equal 1, scheduler[:replica]
    assert_equal "running", scheduler[:state]
    assert_equal "latest", scheduler[:image_tag]
    assert_equal "3 hours ago", scheduler[:running_for]
  end

  def test_parses_replicated_grabber
    containers = parsed_containers
    grabbers = containers.select { |c| c[:service] == "grabber" }

    assert_equal 4, grabbers.size
    assert_equal [1, 2, 3, 4], grabbers.map { |c| c[:replica] }.sort
  end

  def test_parses_restarting_state
    containers = parsed_containers
    grabber2 = containers.find { |c| c[:name] == "booko-grabber-2" }

    assert_equal "restarting", grabber2[:state]
  end

  def test_parses_active_job_with_underscore
    containers = parsed_containers
    active_job = containers.find { |c| c[:name] == "booko-active_job-1" }

    assert_equal "active_job", active_job[:service]
    assert_equal 1, active_job[:replica]
    assert_equal "running", active_job[:state]
  end

  def test_parses_kamal_leftover_containers
    containers = parsed_containers
    kamal = containers.select { |c| c[:name].include?("462dd140f3") }

    assert kamal.size > 0
    assert(kamal.all? { |c| c[:state] == "exited" })
  end

  def test_parses_compose_run_oneoff_containers
    containers = parsed_containers
    oneoffs = containers.select { |c| c[:name].include?("-run-") }

    assert_equal 2, oneoffs.size
    assert(oneoffs.all? { |c| c[:state] == "exited" })
  end

  def test_parses_old_jobs_container
    containers = parsed_containers
    jobs = containers.find { |c| c[:name] == "booko-jobs-1" }

    assert_equal "jobs", jobs[:service]
    assert_equal 1, jobs[:replica]
    assert_equal "exited", jobs[:state]
    assert_equal "12 months ago", jobs[:running_for]
  end

  def test_image_tag_extraction
    containers = parsed_containers
    scheduler = containers.find { |c| c[:name] == "booko-scheduler-1" }
    assert_equal "latest", scheduler[:image_tag]

    kamal = containers.find { |c| c[:name].include?("g02_worker3-grabber02-462dd") && !c[:name].include?("replaced") }
    assert_equal "462dd140f3291658c6b67cfe4fceca0a1afcaf00", kamal[:image_tag]
  end

  def test_running_containers_only
    containers = parsed_containers
    running = containers.select { |c| c[:state] == "running" }

    assert_equal 6, running.size
    services = running.map { |c| c[:service] }.uniq.sort
    assert_equal %w[active_job amazon grabber scheduler], services
  end
end
