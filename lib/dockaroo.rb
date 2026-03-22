# frozen_string_literal: true

require_relative "dockaroo/version"

module Dockaroo
  class Error < StandardError; end
end

require_relative "dockaroo/errors"
require_relative "dockaroo/config"
require_relative "dockaroo/ssh_executor"

require "sshkit"
SSHKit::Backend::Netssh.pool.idle_timeout = 900
SSHKit.config.output_verbosity = :error
require_relative "dockaroo/secrets"
require_relative "dockaroo/env_builder"
require_relative "dockaroo/host_checker"
require_relative "dockaroo/commands/host"
require_relative "dockaroo/commands/check"
require_relative "dockaroo/commands/init"
require_relative "dockaroo/cli"
