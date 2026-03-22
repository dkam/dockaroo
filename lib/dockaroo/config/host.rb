# frozen_string_literal: true

module Dockaroo
  class Config
    Host = Data.define(:name, :user, :port) do
      def initialize(name:, user: nil, port: 22)
        super(name: name, user: user, port: port)
      end

      def to_s
        name
      end
    end
  end
end
