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
