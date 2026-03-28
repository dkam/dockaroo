# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestDeployer < Minitest::Test
  VALID_CONFIG = File.expand_path("fixtures/valid_config.yml", __dir__)

  def setup
    @config = Dockaroo::Config.load(VALID_CONFIG)
    @tmpdir = Dir.mktmpdir
    @secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    @env_builder = Dockaroo::EnvBuilder.new(config: @config, secrets: @secrets)
    @container_manager = Dockaroo::ContainerManager.new(config: @config, env_builder: @env_builder)
    @credentials = Dockaroo::Credentials.new(secrets: @secrets)

    @deployer = Dockaroo::Deployer.new(
      config: @config, env_builder: @env_builder,
      container_manager: @container_manager, credentials: @credentials
    )

    @commands_run = []
    @uploads = []
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def fake_executor
    commands = @commands_run
    uploads = @uploads
    executor = Object.new
    executor.define_singleton_method(:run) do |cmd|
      commands << cmd
      Dockaroo::SSHResult.new(stdout: "", stderr: "", exit_status: 0)
    end
    executor.define_singleton_method(:upload) do |content, path, **opts|
      uploads << { content: content, path: path, opts: opts }
    end
    executor
  end

  def test_deploy_single_service_single_host
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(service_filter: "scheduler", host_filter: "grabber02") do |host:, step:, detail:|
          progress << { host: host, step: step, detail: detail }
        end
      end
    end

    steps = progress.map { |p| p[:step] }
    refute_includes steps, :login
    assert_includes steps, :pull
    assert_includes steps, :upload_secrets
    assert_includes steps, :stop
    assert_includes steps, :remove
    assert_includes steps, :start
  end

  def test_deploy_skip_pull
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(service_filter: "scheduler", host_filter: "grabber02", skip_pull: true) do |host:, step:, detail:|
          progress << { host: host, step: step }
        end
      end
    end

    steps = progress.map { |p| p[:step] }
    refute_includes steps, :pull
  end

  def test_deploy_with_tag
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(tag: "abc123", service_filter: "scheduler", host_filter: "grabber02") do |host:, step:, detail:|
          progress << { host: host, step: step, detail: detail }
        end
      end
    end

    pull_step = progress.find { |p| p[:step] == :pull }
    assert_includes pull_step[:detail], "abc123"
  end

  def test_deploy_replicated_service_stops_all_replicas
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(service_filter: "grabber", host_filter: "grabber01") do |host:, step:, detail:|
          progress << { step: step, detail: detail }
        end
      end
    end

    stop_steps = progress.select { |p| p[:step] == :stop }
    assert_equal 4, stop_steps.size
    assert_includes stop_steps.map { |s| s[:detail] }, "booko-grabber-1"
    assert_includes stop_steps.map { |s| s[:detail] }, "booko-grabber-4"
  end

  def test_deploy_only_services_on_host
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(host_filter: "grabber02") do |host:, step:, detail:|
          progress << { step: step, detail: detail }
        end
      end
    end

    start_steps = progress.select { |p| p[:step] == :start }
    started_names = start_steps.map { |s| s[:detail] }

    assert_equal 7, start_steps.size
    assert(started_names.any? { |n| n.include?("grabber") })
    assert(started_names.any? { |n| n.include?("scheduler") })
    assert(started_names.any? { |n| n.include?("active_job") })
    assert(started_names.any? { |n| n.include?("amazon") })
  end

  def test_deploy_tag_only_affects_default_image_services
    deployer = build_deployer("fixtures/multi_image_config.yml")
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(tag: "abc123", host_filter: "web01") do |host:, step:, detail:|
          progress << { step: step, detail: detail }
        end
      end
    end

    pull_steps = progress.select { |p| p[:step] == :pull }
    pulled_images = pull_steps.map { |p| p[:detail] }

    assert(pulled_images.any? { |img| img.include?("reg.tbdb.info/booko:abc123") })
    assert(pulled_images.any? { |img| img.include?("caddy:2-alpine") })
    assert(pulled_images.any? { |img| img.include?("ghcr.io/techarohq/anubis:latest") })
  end

  def test_deploy_creates_remote_dirs
    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(service_filter: "scheduler", host_filter: "grabber02")
      end
    end

    assert(@commands_run.any? { |cmd| cmd == "mkdir -p ~/booko-services/.dockaroo" })
  end

  def test_deploy_uploads_env_to_remote_dir
    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        @deployer.deploy(service_filter: "scheduler", host_filter: "grabber02")
      end
    end

    assert(@uploads.any? { |u| u[:path] == "~/booko-services/.dockaroo/env" })
  end

  def test_deploy_pulls_unique_images
    deployer = build_deployer("fixtures/multi_image_config.yml")
    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(host_filter: "web01") do |host:, step:, detail:|
          progress << { step: step, detail: detail }
        end
      end
    end

    pull_steps = progress.select { |p| p[:step] == :pull }
    assert_equal 3, pull_steps.size
  end

  private

  def build_deployer(fixture_path)
    config = Dockaroo::Config.load(File.expand_path(fixture_path, __dir__))
    env_builder = Dockaroo::EnvBuilder.new(config: config, secrets: @secrets)
    container_manager = Dockaroo::ContainerManager.new(config: config, env_builder: env_builder)
    Dockaroo::Deployer.new(
      config: config, env_builder: env_builder,
      container_manager: container_manager, credentials: @credentials
    )
  end
end
