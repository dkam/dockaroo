# frozen_string_literal: true

require "test_helper"

class TestSSHResult < Minitest::Test
  def test_success
    result = Dockaroo::SSHResult.new(stdout: "ok", stderr: "", exit_status: 0)
    assert result.success?
  end

  def test_failure
    result = Dockaroo::SSHResult.new(stdout: "", stderr: "error", exit_status: 1)
    refute result.success?
  end
end

class TestSSHExecutor < Minitest::Test
  def test_run_success
    # Printer backend accepts any command without connecting
    executor = Dockaroo::SSHExecutor.new(host: "testhost", user: "testuser")
    result = executor.run("hostname")
    assert result.success?
    assert_equal 0, result.exit_status
  end

  def test_connection_failure_raises_ssh_error
    original_backend = SSHKit.config.backend
    SSHKit.config.backend = SSHKit::Backend::Netssh

    executor = Dockaroo::SSHExecutor.new(host: "badhost")

    Net::SSH.stub(:start, ->(*_args, **_kwargs) { raise Net::SSH::Exception, "connection refused" }) do
      assert_raises(Dockaroo::SSHError) do
        executor.run("hostname")
      end
    end
  ensure
    SSHKit.config.backend = original_backend
  end
end
