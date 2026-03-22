# frozen_string_literal: true

module Dockaroo
  module TUI
    class App
      include Bubbletea::Model

      def initialize(config_path: ".dockaroo.yml")
        @config_path = config_path
        @config = nil
        @screen = :hosts
        @screens = {}
        @width = 80
        @height = 24
      end

      def init
        @config = load_config
        @screens[:hosts] = Screens::Hosts.new(config: @config)
        [self, nil]
      end

      def update(message)
        case message
        when Bubbletea::WindowSizeMessage
          @width = message.width
          @height = message.height
          update_screen_height
          return [self, nil]
        when Bubbletea::KeyMessage
          if @screen == :hosts
            case message.to_s
            when "q", "ctrl+c"
              return [self, Bubbletea.quit]
            end
          end
        when ScreenTransition
          return handle_transition(message)
        end

        current = current_screen
        return [self, nil] unless current

        screen, cmd, transition = current.update(message)
        @screens[@screen] = screen

        if transition
          _, transition_cmd = handle_transition(transition)
          cmd = cmd ? Bubbletea.batch(cmd, transition_cmd) : transition_cmd
        end

        [self, cmd]
      end

      def view
        lines = []

        header_style = Lipgloss::Style.new.bold(true)
        project_name = @config&.project || "no project"
        lines << header_style.render("  Dockaroo — #{project_name}")
        lines << ""

        current = current_screen
        lines << (current ? current.view : "")

        lines.join("\n")
      end

      private

      def current_screen
        @screens[@screen]
      end

      def handle_transition(transition)
        case transition.screen
        when :hosts
          @screens[:hosts]&.refresh
          @screen = :hosts
        when :host_form
          params = transition.params
          @screens[:host_form] = Screens::HostForm.new(
            config: @config,
            mode: params[:mode] || :add,
            host: params[:host]
          )
          @screen = :host_form
        end

        [self, nil]
      end

      def load_config
        Config.load(@config_path)
      rescue ConfigError
        Config.new(path: @config_path)
      end

      def update_screen_height
        hosts_screen = @screens[:hosts]
        return unless hosts_screen

        # Reserve lines for header, footer, and padding
        available = [@height - 6, 5].max
        hosts_screen.table.height = available
      end
    end
  end
end
