# frozen_string_literal: true

require "optparse"

module Dockaroo
  module Commands
    class Deploy
      def self.run(args, config_path: ".dockaroo.yml")
        new(args, config_path: config_path).run
      end

      def initialize(args, config_path: ".dockaroo.yml")
        @args = args
        @config_path = config_path
        @tag = nil
        @service_filter = nil
        @skip_pull = false
      end

      def run
        parser = OptionParser.new do |opts|
          opts.on("--tag TAG", "Deploy specific image tag") { |v| @tag = v }
          opts.on("--service SERVICE", "Deploy specific service only") { |v| @service_filter = v }
          opts.on("--skip-pull", "Skip docker pull (image already on host)") { @skip_pull = true }
        end
        parser.parse!(@args)

        host_filter = @args.first

        config = Config.load(@config_path)
        secrets = Secrets.new
        env_builder = EnvBuilder.new(config: config, secrets: secrets)
        container_manager = ContainerManager.new(config: config, env_builder: env_builder)
        credentials = Credentials.new(secrets: secrets)

        deployer = Deployer.new(
          config: config,
          env_builder: env_builder,
          container_manager: container_manager,
          credentials: credentials
        )

        deployer.deploy(
          tag: @tag,
          host_filter: host_filter,
          service_filter: @service_filter,
          skip_pull: @skip_pull
        ) do |host:, step:, detail:|
          case step
          when :login
            puts "#{host}: Logging in to registry #{detail}"
          when :pull
            puts "#{host}: Pulling #{detail}"
          when :upload_secrets
            puts "#{host}: Uploading secrets"
          when :stop
            puts "#{host}: Stopping #{detail}"
          when :remove
            puts "#{host}: Removing #{detail}"
          when :start
            puts "#{host}: Starting #{detail}"
          end
        end

        puts "Deploy complete."
      rescue ConfigError, SSHError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end
    end
  end
end
