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
    # Build a config with no logging
    raw = {
      "project" => "test",
      "registry" => "registry.example.com",
      "image" => "myapp",
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
      "registry" => "registry.example.com",
      "image" => "myapp",
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

  def test_status_parses_docker_ps
    docker_ps_output = [
      '{"Names":"booko-grabber-1","State":"running","Status":"Up 2 hours","Image":"git.booko.info/booko/booko:abc123","CreatedAt":"2024-01-01","RunningFor":"2 hours ago"}',
      '{"Names":"booko-scheduler","State":"running","Status":"Up 5 minutes","Image":"git.booko.info/booko/booko:abc123","CreatedAt":"2024-01-01","RunningFor":"5 minutes ago"}'
    ].join("\n")

    host = @config.find_host("grabber01")
    fake_executor = Object.new
    fake_executor.define_singleton_method(:run) { |_cmd| Dockaroo::SSHResult.new(stdout: docker_ps_output, stderr: "", exit_status: 0) }

    containers = nil
    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      containers = @manager.status(host: host)
    end

    assert_equal 2, containers.size

    grabber = containers.find { |c| c[:service] == "grabber" }
    assert_equal "booko-grabber-1", grabber[:name]
    assert_equal 1, grabber[:replica]
    assert_equal "running", grabber[:state]
    assert_equal "abc123", grabber[:image_tag]

    scheduler = containers.find { |c| c[:service] == "scheduler" }
    assert_equal "booko-scheduler", scheduler[:name]
    assert_nil scheduler[:replica]
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
