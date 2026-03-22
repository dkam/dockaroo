# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class TestConfig < Minitest::Test
  FIXTURE_PATH = File.expand_path("fixtures/hosts_only.yml", __dir__)

  def test_load_from_file
    config = Dockaroo::Config.load(FIXTURE_PATH)
    assert_equal "testproject", config.project
    assert_equal 3, config.hosts.size
  end

  def test_load_missing_file_raises
    assert_raises(Dockaroo::ConfigError) do
      Dockaroo::Config.load("/nonexistent/path.yml")
    end
  end

  def test_exists
    assert Dockaroo::Config.exists?(FIXTURE_PATH)
    refute Dockaroo::Config.exists?("/nonexistent/path.yml")
  end

  def test_parse_hosts
    config = Dockaroo::Config.load(FIXTURE_PATH)

    grabber01 = config.find_host("grabber01")
    assert_equal "grabber01", grabber01.name
    assert_equal "deploy", grabber01.user
    assert_equal 22, grabber01.port

    grabber02 = config.find_host("grabber02")
    assert_equal 2222, grabber02.port

    webhost = config.find_host("webhost")
    assert_nil webhost.user
    assert_equal 22, webhost.port
  end

  def test_add_host
    config = Dockaroo::Config.new
    config.add_host("newhost", user: "admin")
    assert_equal 1, config.hosts.size
    assert_equal "admin", config.find_host("newhost").user
  end

  def test_add_duplicate_host_raises
    config = Dockaroo::Config.load(FIXTURE_PATH)
    assert_raises(Dockaroo::ConfigError) do
      config.add_host("grabber01")
    end
  end

  def test_remove_host
    config = Dockaroo::Config.load(FIXTURE_PATH)
    config.remove_host("grabber01")
    assert_equal 2, config.hosts.size
    assert_nil config.find_host("grabber01")
  end

  def test_remove_nonexistent_host_raises
    config = Dockaroo::Config.new
    assert_raises(Dockaroo::ConfigError) do
      config.remove_host("nohost")
    end
  end

  def test_update_host
    config = Dockaroo::Config.load(FIXTURE_PATH)
    config.update_host("grabber01", user: "newuser")
    assert_equal "newuser", config.find_host("grabber01").user
    assert_equal 22, config.find_host("grabber01").port
  end

  def test_save_round_trip
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".dockaroo.yml")
      FileUtils.cp(FIXTURE_PATH, path)

      config = Dockaroo::Config.load(path)
      config.add_host("newhost", user: "root", port: 3333)
      config.save

      reloaded = Dockaroo::Config.load(path)
      assert_equal 4, reloaded.hosts.size
      assert_equal "root", reloaded.find_host("newhost").user
      assert_equal 3333, reloaded.find_host("newhost").port
    end
  end

  def test_save_preserves_unknown_keys
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".dockaroo.yml")
      FileUtils.cp(FIXTURE_PATH, path)

      config = Dockaroo::Config.load(path)
      config.save

      raw = YAML.safe_load_file(path)
      assert_equal "testproject", raw["project"]
      assert_equal "registry.example.com", raw["registry"]
      assert_equal "myapp/myapp", raw["image"]
    end
  end

  def test_find_host_returns_nil_for_unknown
    config = Dockaroo::Config.new
    assert_nil config.find_host("nohost")
  end
end

class TestConfigServices < Minitest::Test
  VALID_CONFIG = File.expand_path("fixtures/valid_config.yml", __dir__)

  def test_top_level_accessors
    config = Dockaroo::Config.load(VALID_CONFIG)
    assert_equal "booko", config.project
    assert_equal "git.booko.info", config.registry
    assert_equal "booko/booko", config.image
    assert_equal "latest", config.tag
  end

  def test_full_image
    config = Dockaroo::Config.load(VALID_CONFIG)
    assert_equal "git.booko.info/booko/booko:latest", config.full_image
    assert_equal "git.booko.info/booko/booko:abc123", config.full_image(tag: "abc123")
  end

  def test_parse_services
    config = Dockaroo::Config.load(VALID_CONFIG)
    assert_equal 4, config.services.size
  end

  def test_service_basic_fields
    config = Dockaroo::Config.load(VALID_CONFIG)
    grabber = config.find_service("grabber")

    assert_equal "grabber", grabber.name
    assert_equal "bundle exec bin/booko -W", grabber.cmd
    assert_equal %w[grabber01 grabber02], grabber.hosts
    assert_equal 4, grabber.replicas
    assert grabber.replicated?
  end

  def test_service_single_replica
    config = Dockaroo::Config.load(VALID_CONFIG)
    scheduler = config.find_service("scheduler")

    assert_equal 1, scheduler.replicas
    refute scheduler.replicated?
  end

  def test_defaults_merged_into_service
    config = Dockaroo::Config.load(VALID_CONFIG)
    grabber = config.find_service("grabber")

    assert_equal "host", grabber.network
    assert_equal "on-failure", grabber.restart
    assert_equal({ max_size: "50m", max_file: 5 }, grabber.logging)
    assert_includes grabber.volumes, "./log:/rails/log"
  end

  def test_environment_merged
    config = Dockaroo::Config.load(VALID_CONFIG)
    amazon = config.find_service("amazon")

    # Has defaults env
    assert_equal "2", amazon.environment["MALLOC_ARENA_MAX"]
    assert_equal "1", amazon.environment["RUBY_YJIT_ENABLE"]
    # Plus service-specific env
    assert_equal "true", amazon.environment["AMAZON_SPECIFIC"]
  end

  def test_volumes_merged
    config = Dockaroo::Config.load(VALID_CONFIG)
    amazon = config.find_service("amazon")

    assert_includes amazon.volumes, "./log:/rails/log"    # from defaults
    assert_includes amazon.volumes, "./data:/data"         # from service
    assert_equal 2, amazon.volumes.size
  end

  def test_container_naming_replicated
    config = Dockaroo::Config.load(VALID_CONFIG)
    grabber = config.find_service("grabber")

    assert_equal "booko-grabber-1", grabber.container_name("booko", 1)
    assert_equal "booko-grabber-4", grabber.container_name("booko", 4)
  end

  def test_container_naming_single
    config = Dockaroo::Config.load(VALID_CONFIG)
    scheduler = config.find_service("scheduler")

    assert_equal "booko-scheduler", scheduler.container_name("booko")
  end

  def test_find_service_returns_nil_for_unknown
    config = Dockaroo::Config.load(VALID_CONFIG)
    assert_nil config.find_service("nonexistent")
  end

  def test_empty_services
    config = Dockaroo::Config.new
    assert_equal [], config.services
  end

  def test_default_tag
    config = Dockaroo::Config.new(raw: { "image" => "myapp" })
    assert_equal "latest", config.tag
  end
end
