# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

class TestSecrets < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def write_secrets(filename, content)
    File.write(File.join(@tmpdir, filename), content)
  end

  def test_load_basic
    write_secrets("secrets", "DATABASE_URL=postgres://localhost/myapp\nREDIS_URL=redis://localhost\n")
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("anyhost")
    assert_equal "postgres://localhost/myapp", result["DATABASE_URL"]
    assert_equal "redis://localhost", result["REDIS_URL"]
  end

  def test_comments_and_blank_lines
    write_secrets("secrets", "# This is a comment\n\nKEY=value\n\n# Another comment\n")
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("anyhost")
    assert_equal({ "KEY" => "value" }, result)
  end

  def test_quoted_values
    write_secrets("secrets", "DOUBLE=\"hello world\"\nSINGLE='foo bar'\nNONE=plain\n")
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("anyhost")
    assert_equal "hello world", result["DOUBLE"]
    assert_equal "foo bar", result["SINGLE"]
    assert_equal "plain", result["NONE"]
  end

  def test_value_with_equals
    write_secrets("secrets", "URL=postgres://user:pass@host/db?opt=val\n")
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("anyhost")
    assert_equal "postgres://user:pass@host/db?opt=val", result["URL"]
  end

  def test_host_overrides
    write_secrets("secrets", "DATABASE_URL=postgres://default\nREDIS_URL=redis://default\n")
    write_secrets("secrets.grabber01", "DATABASE_URL=postgres://grabber01\n")
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("grabber01")
    assert_equal "postgres://grabber01", result["DATABASE_URL"]
    assert_equal "redis://default", result["REDIS_URL"]
  end

  def test_missing_base_file
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("anyhost")
    assert_equal({}, result)
  end

  def test_missing_host_file
    write_secrets("secrets", "KEY=base\n")
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    result = secrets.load_for_host("nooverrides")
    assert_equal({ "KEY" => "base" }, result)
  end

  def test_missing_directory
    secrets = Dockaroo::Secrets.new(base_dir: "/nonexistent/path")
    result = secrets.load_for_host("anyhost")
    assert_equal({}, result)
  end
end
