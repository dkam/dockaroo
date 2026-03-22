# frozen_string_literal: true

require "test_helper"

class TestDockaroo < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::Dockaroo::VERSION
  end

  def test_error_hierarchy
    assert Dockaroo::ConfigError < Dockaroo::Error
    assert Dockaroo::SSHError < Dockaroo::Error
    assert Dockaroo::DockerError < Dockaroo::Error
  end
end
