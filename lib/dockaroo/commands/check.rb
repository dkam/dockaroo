# frozen_string_literal: true

module Dockaroo
  module Commands
    class Check
      STATUS_LABELS = {
        ok: "OK",
        warning: "WARN",
        error: "FAIL"
      }.freeze

      def self.run(args, config_path: ".dockaroo.yml")
        new(args, config_path: config_path).run
      end

      def initialize(args, config_path: ".dockaroo.yml")
        @args = args
        @config_path = config_path
      end

      def run
        config = Config.load(@config_path)
        host_name = @args.first

        hosts = if host_name
                  host = config.find_host(host_name)
                  unless host
                    $stderr.puts "Error: Host not found: #{host_name}"
                    exit 1
                  end
                  [host]
                else
                  config.hosts
                end

        if hosts.empty?
          puts "No hosts configured. Add one with: dockaroo host add <name> --user <user>"
          return
        end

        hosts.each_with_index do |host, i|
          puts if i > 0
          check_host(host)
        end
      rescue ConfigError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      private

      def check_host(host)
        puts "#{host.name}:"
        checker = HostChecker.new(host: host.name, user: host.user, port: host.port)
        results = checker.check_all

        results.each do |result|
          label = STATUS_LABELS[result.status]
          puts "  #{result.name}: #{label} (#{result.detail})"
        end
      end
    end
  end
end
