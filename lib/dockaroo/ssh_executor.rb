# frozen_string_literal: true

require "sshkit"

module Dockaroo
  SSHResult = Data.define(:stdout, :stderr, :exit_status) do
    def success? = exit_status == 0
  end

  class SSHExecutor
    def initialize(host:, user: nil, port: 22)
      @sshkit_host = SSHKit::Host.new(hostname: host, user: user, port: port)
    end

    def run(command)
      stdout = +""
      stderr = +""
      exit_status = 0

      backend = SSHKit.config.backend.new(@sshkit_host) do
        begin
          stdout << capture(command, strip: false)
        rescue SSHKit::Command::Failed => e
          exit_status = e.cause&.exit_status || 1
          stderr << e.message
        end
      end
      backend.run

      SSHResult.new(stdout: stdout.chomp, stderr: stderr.chomp, exit_status: exit_status)
    rescue SSHKit::Runner::ExecuteError, Net::SSH::Exception, Errno::ECONNREFUSED,
           Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError, IOError => e
      raise SSHError, "Failed to connect to #{@sshkit_host.hostname}: #{e.message}"
    end

    def upload(content, remote_path, mode: nil)
      io = content.is_a?(StringIO) ? content : StringIO.new(content)

      backend = SSHKit.config.backend.new(@sshkit_host) do
        upload!(io, remote_path)
        execute(:chmod, mode, remote_path) if mode
      end
      backend.run
    rescue SSHKit::Runner::ExecuteError, Net::SSH::Exception, Errno::ECONNREFUSED,
           Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError, IOError => e
      raise SSHError, "Failed to upload to #{@sshkit_host.hostname}: #{e.message}"
    end

  end
end
