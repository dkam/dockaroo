# frozen_string_literal: true

require "test_helper"

class TestCLI < Minitest::Test
  def test_version_long_flag
    out, = capture_io { Dockaroo::CLI.start(["--version"]) }
    assert_equal "dockaroo #{Dockaroo::VERSION}\n", out
  end

  def test_version_short_flag
    out, = capture_io { Dockaroo::CLI.start(["-v"]) }
    assert_equal "dockaroo #{Dockaroo::VERSION}\n", out
  end

  # TUI launch (no args) requires a terminal — skip in test suite
  # Verified manually via: bundle exec dockaroo

  def test_unknown_command_exits_with_error
    assert_raises(SystemExit) do
      capture_io { Dockaroo::CLI.start(["bogus"]) }
    end
  end

  def test_unknown_command_shows_usage
    _, err = capture_io do
      Dockaroo::CLI.start(["bogus"])
    rescue SystemExit
      # expected
    end
    assert_includes err, "Usage:"
  end

  def test_unimplemented_commands_are_recognized
    %w[status deploy logs stop start restart scale].each do |cmd|
      _, err = capture_io do
        Dockaroo::CLI.start([cmd])
      rescue SystemExit
        # expected — not yet implemented
      end
      assert_includes err, "not yet implemented", "Command '#{cmd}' should be recognized"
    end
  end

  def test_host_command_dispatches
    _, err = capture_io do
      Dockaroo::CLI.start(["host"])
    rescue SystemExit
      # expected — no subcommand given
    end
    assert_includes err, "Subcommands:"
  end
end
