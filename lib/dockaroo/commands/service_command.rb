# frozen_string_literal: true

require "optparse"

module Dockaroo
  module Commands
    class ServiceCommand
      def self.run(args, config_path: ".dockaroo.yml")
        new(args, config_path: config_path).run
      end

      def initialize(args, config_path: ".dockaroo.yml")
        @args = args
        @config_path = config_path
        @host_filter = nil
      end

      private

      def parse_options(verb)
        parser = OptionParser.new do |opts|
          opts.on("--host HOST", "#{verb} on specific host only") { |v| @host_filter = v }
        end
        parser.parse!(@args)
      end

      def require_service_arg(verb)
        service_name = @args.shift
        unless service_name
          $stderr.puts "Usage: dockaroo #{verb} <service> [--host HOST]"
          exit 1
        end
        service_name
      end

      def load_config_and_service(service_name)
        config = Config.load(@config_path)
        service = config.find_service(service_name)
        unless service
          $stderr.puts "Error: Service not found: #{service_name}"
          exit 1
        end
        [config, service]
      end

      def build_manager(config)
        secrets = Secrets.new
        env_builder = EnvBuilder.new(config: config, secrets: secrets)
        ContainerManager.new(config: config, env_builder: env_builder)
      end

      def resolve_hosts(config, service)
        if @host_filter
          host = config.find_host(@host_filter)
          unless host
            $stderr.puts "Error: Host not found: #{@host_filter}"
            exit 1
          end
          [host]
        else
          service.hosts.filter_map { |name| config.find_host(name) }
        end
      end

      def each_replica(service)
        if service.replicated?
          (1..service.replicas).each { |i| yield i }
        else
          yield nil
        end
      end
    end
  end
end
