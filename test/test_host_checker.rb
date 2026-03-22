# frozen_string_literal: true

require "test_helper"

class TestHostChecker < Minitest::Test
  def make_executor(&block)
    executor = Object.new
    executor.define_singleton_method(:run, &block)
    executor
  end

  def test_check_docker_installed
    executor = make_executor { |cmd|
      Dockaroo::SSHResult.new(stdout: "Docker version 27.5.1, build 9f9e405", stderr: "", exit_status: 0)
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_docker
    assert_equal :ok, result.status
    assert_equal "27.5.1", result.detail
  end

  def test_check_docker_not_installed
    executor = make_executor { |cmd|
      Dockaroo::SSHResult.new(stdout: "", stderr: "command not found", exit_status: 127)
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_docker
    assert_equal :error, result.status
  end

  def test_check_docker_group_member
    executor = make_executor { |cmd|
      Dockaroo::SSHResult.new(stdout: "deploy docker sudo", stderr: "", exit_status: 0)
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_docker_group
    assert_equal :ok, result.status
    assert_includes result.detail, "docker group"
  end

  def test_check_docker_group_root
    executor = make_executor { |cmd|
      case cmd
      when "id -nG"
        Dockaroo::SSHResult.new(stdout: "root", stderr: "", exit_status: 0)
      when "id -u"
        Dockaroo::SSHResult.new(stdout: "0", stderr: "", exit_status: 0)
      end
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_docker_group
    assert_equal :ok, result.status
    assert_includes result.detail, "root"
  end

  def test_check_docker_group_not_member
    executor = make_executor { |cmd|
      case cmd
      when "id -nG"
        Dockaroo::SSHResult.new(stdout: "deploy sudo", stderr: "", exit_status: 0)
      when "id -u"
        Dockaroo::SSHResult.new(stdout: "1000", stderr: "", exit_status: 0)
      end
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_docker_group
    assert_equal :error, result.status
  end

  def test_check_disk_space_ok
    executor = make_executor { |cmd|
      output = "Filesystem      1G-blocks  Used Available Use% Mounted on\n/dev/sda1             50G   5G       45G  10% /\n"
      Dockaroo::SSHResult.new(stdout: output, stderr: "", exit_status: 0)
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_disk_space
    assert_equal :ok, result.status
    assert_includes result.detail, "45GB"
  end

  def test_check_disk_space_low
    executor = make_executor { |cmd|
      output = "Filesystem      1G-blocks  Used Available Use% Mounted on\n/dev/sda1             50G  47G        3G  94% /\n"
      Dockaroo::SSHResult.new(stdout: output, stderr: "", exit_status: 0)
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_disk_space
    assert_equal :warning, result.status
    assert_includes result.detail, "3GB"
  end

  def test_check_ssh_success
    executor = make_executor { |cmd|
      Dockaroo::SSHResult.new(stdout: "testhost", stderr: "", exit_status: 0)
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_ssh
    assert_equal :ok, result.status
  end

  def test_check_ssh_failure
    executor = make_executor { |cmd|
      raise Dockaroo::SSHError, "Connection refused"
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    result = checker.check_ssh
    assert_equal :error, result.status
  end

  def test_check_all_short_circuits_on_ssh_failure
    executor = make_executor { |cmd|
      raise Dockaroo::SSHError, "Connection refused"
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    results = checker.check_all
    assert_equal 1, results.length
    assert_equal "SSH connection", results.first.name
    assert_equal :error, results.first.status
  end

  def test_check_all_runs_all_on_success
    executor = make_executor { |cmd|
      case cmd
      when "hostname"
        Dockaroo::SSHResult.new(stdout: "testhost", stderr: "", exit_status: 0)
      when "docker --version"
        Dockaroo::SSHResult.new(stdout: "Docker version 27.5.1, build abc", stderr: "", exit_status: 0)
      when "id -nG"
        Dockaroo::SSHResult.new(stdout: "deploy docker", stderr: "", exit_status: 0)
      else
        output = "Filesystem      1G-blocks  Used Available Use% Mounted on\n/dev/sda1             50G   5G       45G  10% /\n"
        Dockaroo::SSHResult.new(stdout: output, stderr: "", exit_status: 0)
      end
    }
    checker = Dockaroo::HostChecker.new(host: "testhost", executor: executor)
    results = checker.check_all
    assert_equal 4, results.length
    assert(results.all? { |r| r.status == :ok })
  end
end
