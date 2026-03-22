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

    class HostCheckResult < Bubbletea::Message
      attr_reader :host_name, :results

      def initialize(host_name:, results:)
        super()
        @host_name = host_name
        @results = results
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
