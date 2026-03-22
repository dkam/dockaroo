# frozen_string_literal: true

module Dockaroo
  class HostChecker
    CheckResult = Data.define(:name, :status, :detail)
    # status: :ok, :warning, :error

    def initialize(host:, user: nil, port: 22, executor: nil)
      @host = host
      @executor = executor || SSHExecutor.new(host: host, user: user, port: port)
    end

    def check_all
      results = []

      ssh_result = check_ssh
      results << ssh_result
      return results if ssh_result.status == :error

      results << check_docker
      results << check_docker_group
      results << check_disk_space
      results
    end

    def check_ssh
      result = @executor.run("hostname")
      CheckResult.new(name: "SSH connection", status: :ok, detail: result.stdout)
    rescue SSHError => e
      CheckResult.new(name: "SSH connection", status: :error, detail: e.message)
    end

    def check_docker
      result = @executor.run("docker --version")
      if result.success?
        version = result.stdout[/Docker version ([\d.]+)/, 1] || "unknown"
        CheckResult.new(name: "Docker installed", status: :ok, detail: version)
      else
        CheckResult.new(name: "Docker installed", status: :error, detail: "not found")
      end
    rescue SSHError => e
      CheckResult.new(name: "Docker installed", status: :error, detail: e.message)
    end

    def check_docker_group
      result = @executor.run("id -nG")
      if result.success?
        groups = result.stdout.split
        if groups.include?("docker")
          CheckResult.new(name: "Docker group", status: :ok, detail: "in docker group")
        else
          # Check if root
          uid_result = @executor.run("id -u")
          if uid_result.success? && uid_result.stdout.strip == "0"
            CheckResult.new(name: "Docker group", status: :ok, detail: "running as root")
          else
            CheckResult.new(name: "Docker group", status: :error, detail: "user not in docker group")
          end
        end
      else
        CheckResult.new(name: "Docker group", status: :error, detail: result.stderr)
      end
    rescue SSHError => e
      CheckResult.new(name: "Docker group", status: :error, detail: e.message)
    end

    def check_disk_space
      result = @executor.run("df -BG /var/lib/docker 2>/dev/null || df -BG /")
      if result.success?
        # Parse df output: second line, 4th column is available space
        lines = result.stdout.lines
        if lines.length >= 2
          fields = lines[1].split
          available = fields[3]&.gsub("G", "")&.to_i || 0
          if available < 5
            CheckResult.new(name: "Disk space", status: :warning, detail: "#{available}GB free")
          else
            CheckResult.new(name: "Disk space", status: :ok, detail: "#{available}GB free")
          end
        else
          CheckResult.new(name: "Disk space", status: :warning, detail: "could not parse df output")
        end
      else
        CheckResult.new(name: "Disk space", status: :warning, detail: "could not check")
      end
    rescue SSHError => e
      CheckResult.new(name: "Disk space", status: :error, detail: e.message)
    end
  end
end
