# frozen_string_literal: true

require "net/ssh"

module Dockaroo
  SSHResult = Data.define(:stdout, :stderr, :exit_status) do
    def success? = exit_status == 0
  end

  class SSHExecutor
    def initialize(host:, user: nil, port: 22)
      @host = host
      @user = user
      @port = port
      @session = nil
    end

    def run(command)
      connect unless @session

      stdout = +""
      stderr = +""
      exit_status = nil

      @session.open_channel do |channel|
        channel.exec(command) do |ch, success|
          raise SSHError, "Failed to execute command on #{@host}" unless success

          ch.on_data { |_, data| stdout << data }
          ch.on_extended_data { |_, _, data| stderr << data }
          ch.on_request("exit-status") { |_, buf| exit_status = buf.read_long }
        end
      end

      @session.loop

      SSHResult.new(stdout: stdout.chomp, stderr: stderr.chomp, exit_status: exit_status || 0)
    rescue Net::SSH::Exception, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
           Errno::ETIMEDOUT, SocketError => e
      raise SSHError, "Failed to connect to #{@host}: #{e.message}"
    end

    def close
      @session&.close
      @session = nil
    end

    private

    def connect
      @session = Net::SSH.start(@host, @user, port: @port, non_interactive: true)
    rescue Net::SSH::Exception, Errno::ECONNREFUSED, Errno::EHOSTUNREACH,
           Errno::ETIMEDOUT, SocketError => e
      raise SSHError, "Failed to connect to #{@host}: #{e.message}"
    end
  end
end
