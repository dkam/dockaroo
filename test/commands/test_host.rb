# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class TestHostCommand < Minitest::Test
  FIXTURE_PATH = File.expand_path("../fixtures/hosts_only.yml", __dir__)

  def setup
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, ".dockaroo.yml")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_host_add
    out, = capture_io do
      Dockaroo::Commands::Host.run(["add", "myhost", "--user", "deploy"], config_path: @config_path)
    end
    assert_includes out, "Added host: myhost"

    config = Dockaroo::Config.load(@config_path)
    assert_equal 1, config.hosts.size
    assert_equal "deploy", config.find_host("myhost").user
  end

  def test_host_add_to_existing_config
    FileUtils.cp(FIXTURE_PATH, @config_path)

    out, = capture_io do
      Dockaroo::Commands::Host.run(["add", "newhost", "--user", "root"], config_path: @config_path)
    end
    assert_includes out, "Added host: newhost"

    config = Dockaroo::Config.load(@config_path)
    assert_equal 4, config.hosts.size
  end

  def test_host_remove
    FileUtils.cp(FIXTURE_PATH, @config_path)

    out, = capture_io do
      Dockaroo::Commands::Host.run(["remove", "grabber01"], config_path: @config_path)
    end
    assert_includes out, "Removed host: grabber01"

    config = Dockaroo::Config.load(@config_path)
    assert_nil config.find_host("grabber01")
  end

  def test_host_list
    FileUtils.cp(FIXTURE_PATH, @config_path)

    out, = capture_io do
      Dockaroo::Commands::Host.run(["list"], config_path: @config_path)
    end
    assert_includes out, "grabber01"
    assert_includes out, "grabber02"
    assert_includes out, "webhost"
    assert_includes out, "deploy"
  end

  def test_host_list_empty
    File.write(@config_path, YAML.dump({}))

    out, = capture_io do
      Dockaroo::Commands::Host.run(["list"], config_path: @config_path)
    end
    assert_includes out, "No hosts configured"
  end

  def test_host_add_with_port
    out, = capture_io do
      Dockaroo::Commands::Host.run(["add", "myhost", "--user", "root", "--port", "2222"], config_path: @config_path)
    end
    assert_includes out, "Added host: myhost"

    config = Dockaroo::Config.load(@config_path)
    assert_equal 2222, config.find_host("myhost").port
  end
end
