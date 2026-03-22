# frozen_string_literal: true

module Dockaroo
  module TUI
    module Screens
      class Hosts
        attr_reader :table

        def initialize(config:)
          @config = config
          @statuses = {}
          @confirming_delete = false
          @table = Bubbles::Table.new(
            columns: [
              { title: "HOST", width: 20 },
              { title: "USER", width: 15 },
              { title: "PORT", width: 6 },
              { title: "STATUS", width: 15 }
            ],
            rows: build_rows,
            height: 15
          )
          @table.focus = true
        end

        def update(message)
          case message
          when Bubbletea::KeyMessage
            return handle_key(message)
          when SSHTestResult
            return handle_ssh_result(message)
          when HostCheckResult
            return handle_check_result(message)
          end

          @table, cmd = @table.update(message)
          [self, cmd, nil]
        end

        def view
          lines = []
          lines << @table.view
          lines << ""

          if @confirming_delete
            host = selected_host
            lines << "  Delete #{host&.name}? (y/n)"
          else
            lines << "  a:add  e:edit  d:delete  t:test ssh  c:check  q:quit"
          end

          lines.join("\n")
        end

        def refresh
          @table.rows = build_rows
        end

        private

        def handle_key(message)
          if @confirming_delete
            return handle_delete_confirmation(message)
          end

          case message.to_s
          when "a"
            transition = ScreenTransition.new(screen: :host_form, params: { mode: :add })
            [self, nil, transition]
          when "e", "enter"
            host = selected_host
            return [self, nil, nil] unless host

            transition = ScreenTransition.new(screen: :host_form, params: { mode: :edit, host: host })
            [self, nil, transition]
          when "d"
            host = selected_host
            return [self, nil, nil] unless host

            @confirming_delete = true
            [self, nil, nil]
          when "t"
            host = selected_host
            return [self, nil, nil] unless host

            @statuses[host.name] = "testing..."
            @table.rows = build_rows

            cmd = proc {
              begin
                executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)
                result = executor.run("hostname")
                SSHTestResult.new(host_name: host.name, success: true, detail: result.stdout)
              rescue SSHError => e
                SSHTestResult.new(host_name: host.name, success: false, detail: e.message)
              end
            }

            [self, cmd, nil]
          when "c"
            host = selected_host
            return [self, nil, nil] unless host

            @statuses[host.name] = "checking..."
            @table.rows = build_rows

            cmd = proc {
              begin
                checker = HostChecker.new(host: host.name, user: host.user, port: host.port)
                results = checker.check_all
                HostCheckResult.new(host_name: host.name, results: results)
              rescue SSHError => e
                failed = [HostChecker::CheckResult.new(name: "SSH connection", status: :error, detail: e.message)]
                HostCheckResult.new(host_name: host.name, results: failed)
              end
            }

            [self, cmd, nil]
          else
            @table, cmd = @table.update(message)
            [self, cmd, nil]
          end
        end

        def handle_delete_confirmation(message)
          case message.to_s
          when "y"
            host = selected_host
            if host
              @config.remove_host(host.name)
              @config.save
              @statuses.delete(host.name)
              @table.rows = build_rows
            end
            @confirming_delete = false
            [self, nil, nil]
          else
            @confirming_delete = false
            [self, nil, nil]
          end
        end

        def handle_check_result(message)
          problems = message.results.select { |r| r.status != :ok }
          @statuses[message.host_name] = if problems.empty?
                                           "ok"
                                         else
                                           problems.first.detail
                                         end
          @table.rows = build_rows
          [self, nil, nil]
        end

        def handle_ssh_result(message)
          @statuses[message.host_name] = message.success ? "ssh ok" : "ssh error"
          @table.rows = build_rows
          [self, nil, nil]
        end

        def selected_host
          idx = @table.selected_row
          @config.hosts[idx]
        end

        def build_rows
          @config.hosts.map do |host|
            status = @statuses[host.name] || "—"
            [host.name, host.user || "(current)", host.port.to_s, status]
          end
        end
      end
    end
  end
end
