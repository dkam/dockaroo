# frozen_string_literal: true

require_relative "dockaroo/version"

module Dockaroo
  class Error < StandardError; end
end

require_relative "dockaroo/errors"
require_relative "dockaroo/config"
require_relative "dockaroo/ssh_executor"
require_relative "dockaroo/commands/host"
require_relative "dockaroo/commands/init"
require_relative "dockaroo/cli"
