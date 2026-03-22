# frozen_string_literal: true

require_relative "dockaroo/version"

module Dockaroo
  class Error < StandardError; end
end

require_relative "dockaroo/errors"
require_relative "dockaroo/cli"
