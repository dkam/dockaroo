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
    # Build a fake session that simulates Net::SSH channel execution
    fake_session = Object.new
    def fake_session.open_channel(&block)
      channel = Object.new
      def channel.exec(cmd)
        yield self, true
      end
      def channel.on_data
        yield self, "testhostname"
      end
      def channel.on_extended_data
        # no stderr
      end
      def channel.on_request(type)
        buf = Object.new
        def buf.read_long = 0
        yield self, buf
      end
      block.call(channel)
    end
    def fake_session.loop = nil

    start_stub = proc { |*_args, **_kwargs| fake_session }

    Net::SSH.stub(:start, start_stub) do
      executor = Dockaroo::SSHExecutor.new(host: "testhost", user: "testuser")
      result = executor.run("hostname")
      assert_equal "testhostname", result.stdout
      assert result.success?
    end
  end

  def test_connection_failure_raises_ssh_error
    start_stub = proc { |*_args, **_kwargs| raise Net::SSH::Exception, "connection refused" }

    Net::SSH.stub(:start, start_stub) do
      executor = Dockaroo::SSHExecutor.new(host: "badhost")
      assert_raises(Dockaroo::SSHError) do
        executor.run("hostname")
      end
    end
  end
end
