# frozen_string_literal: true

module Dockaroo
  module Commands
    class Stop < ServiceCommand
      def run
        parse_options("Stop")
        service_name = require_service_arg("stop")
        config, service = load_config_and_service(service_name)
        manager = build_manager(config)
        hosts = resolve_hosts(config, service)

        hosts.each do |host|
          each_replica(service) do |replica|
            name = service.container_name(config.project, replica)
            print "Stopping #{name} on #{host.name}... "
            manager.stop(service: service, host: host, replica: replica)
            puts "done"
          end
        end
      rescue ConfigError, SSHError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end
    end
  end
end
