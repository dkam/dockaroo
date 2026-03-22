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
    deployer = Dockaroo::Deployer.new(
      config: @config, env_builder: @env_builder,
      container_manager: @container_manager, credentials: @credentials
    )

    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(service_filter: "scheduler", host_filter: "grabber02") do |host:, step:, detail:|
          progress << { host: host, step: step, detail: detail }
        end
      end
    end

    # Check progress steps
    steps = progress.map { |p| p[:step] }
    assert_includes steps, :login
    assert_includes steps, :pull
    assert_includes steps, :upload_secrets
    assert_includes steps, :stop
    assert_includes steps, :remove
    assert_includes steps, :start
  end

  def test_deploy_skip_pull
    deployer = Dockaroo::Deployer.new(
      config: @config, env_builder: @env_builder,
      container_manager: @container_manager, credentials: @credentials
    )

    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(service_filter: "scheduler", host_filter: "grabber02", skip_pull: true) do |host:, step:, detail:|
          progress << { host: host, step: step }
        end
      end
    end

    steps = progress.map { |p| p[:step] }
    refute_includes steps, :pull
  end

  def test_deploy_with_tag
    deployer = Dockaroo::Deployer.new(
      config: @config, env_builder: @env_builder,
      container_manager: @container_manager, credentials: @credentials
    )

    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(tag: "abc123", service_filter: "scheduler", host_filter: "grabber02") do |host:, step:, detail:|
          progress << { host: host, step: step, detail: detail }
        end
      end
    end

    pull_step = progress.find { |p| p[:step] == :pull }
    assert_includes pull_step[:detail], "abc123"
  end

  def test_deploy_replicated_service_stops_all_replicas
    deployer = Dockaroo::Deployer.new(
      config: @config, env_builder: @env_builder,
      container_manager: @container_manager, credentials: @credentials
    )

    progress = []

    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(service_filter: "grabber", host_filter: "grabber01") do |host:, step:, detail:|
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
    deployer = Dockaroo::Deployer.new(
      config: @config, env_builder: @env_builder,
      container_manager: @container_manager, credentials: @credentials
    )

    progress = []

    # grabber02 has: grabber, active_job, scheduler, amazon
    Dockaroo::SSHExecutor.stub(:new, fake_executor) do
      $stdin.stub(:tty?, false) do
        deployer.deploy(host_filter: "grabber02") do |host:, step:, detail:|
          progress << { step: step, detail: detail }
        end
      end
    end

    start_steps = progress.select { |p| p[:step] == :start }
    started_names = start_steps.map { |s| s[:detail] }

    # grabber has 4 replicas + active_job + scheduler + amazon = 7 starts
    assert_equal 7, start_steps.size
    assert(started_names.any? { |n| n.include?("grabber") })
    assert(started_names.any? { |n| n.include?("scheduler") })
    assert(started_names.any? { |n| n.include?("active_job") })
    assert(started_names.any? { |n| n.include?("amazon") })
  end
end
