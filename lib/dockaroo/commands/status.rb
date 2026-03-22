# frozen_string_literal: true

require "optparse"

module Dockaroo
  module Commands
    class Status
      def self.run(args, config_path: ".dockaroo.yml")
        new(args, config_path: config_path).run
      end

      def initialize(args, config_path: ".dockaroo.yml")
        @args = args
        @config_path = config_path
        @service_filter = nil
      end

      def run
        parser = OptionParser.new do |opts|
          opts.on("--service SERVICE", "Filter by service") { |v| @service_filter = v }
        end
        parser.parse!(@args)

        host_filter = @args.first

        config = Config.load(@config_path)
        secrets = Secrets.new
        env_builder = EnvBuilder.new(config: config, secrets: secrets)
        manager = ContainerManager.new(config: config, env_builder: env_builder)

        hosts = if host_filter
                  host = config.find_host(host_filter)
                  unless host
                    $stderr.puts "Error: Host not found: #{host_filter}"
                    exit 1
                  end
                  [host]
                else
                  config.hosts
                end

        if hosts.empty?
          puts "No hosts configured."
          return
        end

        puts format("%-12s %-14s %-8s %-10s %-12s %s", "HOST", "SERVICE", "REPLICA", "STATUS", "IMAGE TAG", "UPTIME")
        puts "-" * 70

        hosts.each do |host|
          containers = manager.status(host: host)

          containers.each do |c|
            next if @service_filter && c[:service] != @service_filter

            replica = c[:replica] ? c[:replica].to_s : "-"
            state = c[:state]
            puts format("%-12s %-14s %-8s %-10s %-12s %s", host.name, c[:service], replica, state, c[:image_tag], c[:running_for])
          end
        end
      rescue ConfigError, SSHError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end
    end
  end
end
