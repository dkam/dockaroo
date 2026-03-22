# frozen_string_literal: true

require "test_helper"
require "tmpdir"

class TestCredentials < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    ENV.delete("DOCKAROO_REGISTRY_USERNAME")
    ENV.delete("DOCKAROO_REGISTRY_PASSWORD")
  end

  def test_from_env_vars
    ENV["DOCKAROO_REGISTRY_USERNAME"] = "myuser"
    ENV["DOCKAROO_REGISTRY_PASSWORD"] = "mypass"

    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    creds = Dockaroo::Credentials.new(secrets: secrets)
    result = creds.resolve

    assert_equal "myuser", result[:username]
    assert_equal "mypass", result[:password]
  end

  def test_from_secrets
    File.write(File.join(@tmpdir, "secrets"), <<~SECRETS)
      DOCKAROO_REGISTRY_USERNAME=secretuser
      DOCKAROO_REGISTRY_PASSWORD=secretpass
    SECRETS

    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    creds = Dockaroo::Credentials.new(secrets: secrets)
    result = creds.resolve

    assert_equal "secretuser", result[:username]
    assert_equal "secretpass", result[:password]
  end

  def test_env_vars_take_precedence_over_secrets
    ENV["DOCKAROO_REGISTRY_USERNAME"] = "envuser"
    ENV["DOCKAROO_REGISTRY_PASSWORD"] = "envpass"

    File.write(File.join(@tmpdir, "secrets"), <<~SECRETS)
      DOCKAROO_REGISTRY_USERNAME=secretuser
      DOCKAROO_REGISTRY_PASSWORD=secretpass
    SECRETS

    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    creds = Dockaroo::Credentials.new(secrets: secrets)
    result = creds.resolve

    assert_equal "envuser", result[:username]
  end

  def test_nil_when_no_credentials
    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    creds = Dockaroo::Credentials.new(secrets: secrets)

    # Stub $stdin.tty? to return false so it doesn't prompt
    $stdin.stub(:tty?, false) do
      result = creds.resolve
      assert_nil result
    end
  end

  def test_partial_env_vars_not_sufficient
    ENV["DOCKAROO_REGISTRY_USERNAME"] = "myuser"
    # No password

    secrets = Dockaroo::Secrets.new(base_dir: @tmpdir)
    creds = Dockaroo::Credentials.new(secrets: secrets)

    $stdin.stub(:tty?, false) do
      result = creds.resolve
      assert_nil result
    end
  end
end
