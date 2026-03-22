# frozen_string_literal: true

module Dockaroo
  module TUI
    module Screens
      class HostForm
        FIELDS = [:hostname, :user].freeze

        def initialize(config:, mode: :add, host: nil)
          @config = config
          @mode = mode
          @host = host
          @focus_index = 0
          @error = nil

          @hostname_input = Bubbles::TextInput.new
          @hostname_input.placeholder = "hostname or IP"
          @hostname_input.prompt = "  "

          @user_input = Bubbles::TextInput.new
          @user_input.placeholder = "SSH user (leave blank for current)"
          @user_input.prompt = "  "

          if mode == :edit && host
            @hostname_input.value = host.name
            @user_input.value = host.user || ""
          end

          focus_current_field
        end

        def update(message)
          case message
          when Bubbletea::KeyMessage
            return handle_key(message)
          end

          update_focused_input(message)
          [self, nil, nil]
        end

        def view
          title = @mode == :add ? "Add Host" : "Edit Host"
          lines = []
          lines << "  #{title}"
          lines << ""
          lines << "  Hostname:"
          lines << @hostname_input.view
          lines << ""
          lines << "  User:"
          lines << @user_input.view
          lines << ""

          if @error
            lines << "  Error: #{@error}"
            lines << ""
          end

          lines << "  Tab:next field  Enter:save  Esc:cancel"
          lines.join("\n")
        end

        private

        def handle_key(message)
          case message.to_s
          when "tab"
            @focus_index = (@focus_index + 1) % FIELDS.size
            focus_current_field
            [self, nil, nil]
          when "shift+tab"
            @focus_index = (@focus_index - 1) % FIELDS.size
            focus_current_field
            [self, nil, nil]
          when "enter"
            save
          when "esc"
            transition = ScreenTransition.new(screen: :hosts)
            [self, nil, transition]
          else
            cmd = update_focused_input(message)
            [self, cmd, nil]
          end
        end

        def save
          hostname = @hostname_input.value.strip
          user = @user_input.value.strip
          user = nil if user.empty?

          if hostname.empty?
            @error = "Hostname is required"
            return [self, nil, nil]
          end

          if @mode == :add
            @config.add_host(hostname, user: user)
          else
            @config.update_host(@host.name, user: user)
          end
          @config.save
          @error = nil

          transition = ScreenTransition.new(screen: :hosts)
          [self, nil, transition]
        rescue ConfigError => e
          @error = e.message
          [self, nil, nil]
        end

        def focus_current_field
          @hostname_input.blur
          @user_input.blur

          case FIELDS[@focus_index]
          when :hostname
            @hostname_input.focus
          when :user
            @user_input.focus
          end
        end

        def update_focused_input(message)
          case FIELDS[@focus_index]
          when :hostname
            return nil if @mode == :edit

            @hostname_input, cmd = @hostname_input.update(message)
            cmd
          when :user
            @user_input, cmd = @user_input.update(message)
            cmd
          end
        end
      end
    end
  end
end
