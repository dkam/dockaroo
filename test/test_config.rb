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

  def test_save_preserves_project
    Dir.mktmpdir do |dir|
      path = File.join(dir, ".dockaroo.yml")
      FileUtils.cp(FIXTURE_PATH, path)

      config = Dockaroo::Config.load(path)
      config.save

      raw = YAML.safe_load_file(path)
      assert_equal "testproject", raw["project"]
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
    assert_equal "git.booko.info/booko/booko:latest", config.default_image
  end

  def test_service_inherits_default_image
    config = Dockaroo::Config.load(VALID_CONFIG)
    grabber = config.find_service("grabber")
    assert_equal "git.booko.info/booko/booko:latest", grabber.image
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

  def test_remote_dir_inherited_from_defaults
    config = Dockaroo::Config.load(VALID_CONFIG)
    grabber = config.find_service("grabber")

    assert_equal "~/booko-services", grabber.remote_dir
  end

  def test_remote_dir_defaults_to_home
    raw = {
      "project" => "test",
      "defaults" => { "image" => "myapp:latest" },
      "hosts" => { "host1" => nil },
      "services" => { "worker" => { "cmd" => "ruby worker.rb", "hosts" => ["host1"] } }
    }
    config = Dockaroo::Config.new(raw: raw)
    worker = config.find_service("worker")

    assert_equal "~", worker.remote_dir
  end

  def test_remote_dir_service_overrides_default
    raw = {
      "project" => "test",
      "defaults" => { "image" => "myapp:latest", "remote_dir" => "~/default-dir" },
      "hosts" => { "host1" => nil },
      "services" => {
        "worker" => { "cmd" => "ruby worker.rb", "hosts" => ["host1"], "remote_dir" => "~/custom-dir" }
      }
    }
    config = Dockaroo::Config.new(raw: raw)
    worker = config.find_service("worker")

    assert_equal "~/custom-dir", worker.remote_dir
  end

  def test_environment_merged
    config = Dockaroo::Config.load(VALID_CONFIG)
    amazon = config.find_service("amazon")

    assert_equal "2", amazon.environment["MALLOC_ARENA_MAX"]
    assert_equal "1", amazon.environment["RUBY_YJIT_ENABLE"]
    assert_equal "true", amazon.environment["AMAZON_SPECIFIC"]
  end

  def test_volumes_merged
    config = Dockaroo::Config.load(VALID_CONFIG)
    amazon = config.find_service("amazon")

    assert_includes amazon.volumes, "./log:/rails/log"
    assert_includes amazon.volumes, "./data:/data"
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

  def test_image_with_tag
    service = Dockaroo::Config::Service.new(name: "web", image: "reg.tbdb.info/booko:latest")
    assert_equal "reg.tbdb.info/booko:abc123", service.image_with_tag("abc123")
  end

  def test_image_with_tag_no_existing_tag
    service = Dockaroo::Config::Service.new(name: "web", image: "caddy")
    assert_equal "caddy:2-alpine", service.image_with_tag("2-alpine")
  end

  def test_image_with_tag_docker_hub
    service = Dockaroo::Config::Service.new(name: "web", image: "caddy:2-alpine")
    assert_equal "caddy:latest", service.image_with_tag("latest")
  end
end

class TestConfigMultiImage < Minitest::Test
  MULTI_IMAGE_CONFIG = File.expand_path("fixtures/multi_image_config.yml", __dir__)

  def test_service_overrides_default_image
    config = Dockaroo::Config.load(MULTI_IMAGE_CONFIG)

    caddy = config.find_service("caddy")
    assert_equal "caddy:2-alpine", caddy.image

    anubis = config.find_service("anubis")
    assert_equal "ghcr.io/techarohq/anubis:latest", anubis.image
  end

  def test_service_inherits_default_image
    config = Dockaroo::Config.load(MULTI_IMAGE_CONFIG)

    web = config.find_service("web")
    assert_equal "reg.tbdb.info/booko:latest", web.image

    grabber = config.find_service("grabber")
    assert_equal "reg.tbdb.info/booko:latest", grabber.image
  end

  def test_service_ports
    config = Dockaroo::Config.load(MULTI_IMAGE_CONFIG)
    caddy = config.find_service("caddy")

    assert_equal ["80:80", "443:443"], caddy.ports
  end

  def test_service_without_cmd
    config = Dockaroo::Config.load(MULTI_IMAGE_CONFIG)
    caddy = config.find_service("caddy")

    assert_nil caddy.cmd
  end

  def test_default_image_accessor
    config = Dockaroo::Config.load(MULTI_IMAGE_CONFIG)
    assert_equal "reg.tbdb.info/booko:latest", config.default_image
  end
end

