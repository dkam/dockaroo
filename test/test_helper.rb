# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "dockaroo"

require "minitest/autorun"

# Use Printer backend so no test accidentally makes real SSH connections
SSHKit.config.backend = SSHKit::Backend::Printer
SSHKit::Backend::Netssh.pool = SSHKit::Backend::ConnectionPool.new(0)
