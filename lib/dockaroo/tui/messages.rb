# frozen_string_literal: true

module Dockaroo
  module TUI
    class SSHTestResult < Bubbletea::Message
      attr_reader :host_name, :success, :detail

      def initialize(host_name:, success:, detail:)
        super()
        @host_name = host_name
        @success = success
        @detail = detail
      end
    end

    class ScreenTransition < Bubbletea::Message
      attr_reader :screen, :params

      def initialize(screen:, params: {})
        super()
        @screen = screen
        @params = params
      end
    end
  end
end
