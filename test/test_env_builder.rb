# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class TestEnvBuilder < Minitest::Test
  VALID_CONFIG = File.expand_path("fixtures/valid_config.yml", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @config = Dockaroo::Config.load(VALID_CONFIG)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def write_secrets(filename, content)
    File.write(File.join(@tmpdir, filename), content)
  end

  def test_secrets_file_content
    write_secrets("secrets", "DATABASE_URL=postgres://localhost/myapp\nSECRET_KEY=abc123\n")
    write_secrets("secrets.grabber01", "DATABASE_URL=postgres://grabber01/myapp\n")

    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)

    content = builder.secrets_file_content(host_name: "grabber01")
    assert_includes content, "DATABASE_URL=postgres://grabber01/myapp"
    assert_includes content, "SECRET_KEY=abc123"
  end

  def test_secrets_file_empty_when_no_secrets
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)

    content = builder.secrets_file_content(host_name: "grabber01")
    assert_equal "", content
  end

  def test_env_flags_includes_defaults
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    grabber = @config.find_service("grabber")

    flags = builder.env_flags(service: grabber, host_name: "grabber01", replica: 2)
    assert_includes flags, "MALLOC_ARENA_MAX=2"
    assert_includes flags, "RUBY_YJIT_ENABLE=1"
  end

  def test_env_flags_includes_service_env
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    amazon = @config.find_service("amazon")

    flags = builder.env_flags(service: amazon, host_name: "grabber01")
    assert_includes flags, "AMAZON_SPECIFIC=true"
  end

  def test_env_flags_includes_auto_injected
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    grabber = @config.find_service("grabber")

    flags = builder.env_flags(service: grabber, host_name: "grabber02", replica: 3)
    assert_includes flags, "DOCKAROO_PROJECT=booko"
    assert_includes flags, "DOCKAROO_SERVICE=grabber"
    assert_includes flags, "DOCKAROO_HOST=grabber02"
    assert_includes flags, "DOCKAROO_INSTANCE=3"
  end

  def test_env_flags_no_instance_for_single_replica
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    scheduler = @config.find_service("scheduler")

    flags = builder.env_flags(service: scheduler, host_name: "grabber02")
    refute(flags.any? { |f| f.start_with?("DOCKAROO_INSTANCE=") })
  end

  def test_service_env_overrides_defaults
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    builder = Dockaroo::EnvBuilder.new(config: @config, secrets: secrets)
    amazon = @config.find_service("amazon")

    flags = builder.env_flags(service: amazon, host_name: "grabber01")
    # MALLOC_ARENA_MAX comes from defaults, should still be present
    assert_includes flags, "MALLOC_ARENA_MAX=2"
    # AMAZON_SPECIFIC comes from service
    assert_includes flags, "AMAZON_SPECIFIC=true"
  end
end
