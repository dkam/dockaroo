# frozen_string_literal: true

require "shellwords"

module Dockaroo
  class Deployer
    REMOTE_ENV_PATH = "~/.dockaroo/env"

    def initialize(config:, env_builder:, container_manager:, credentials:)
      @config = config
      @env_builder = env_builder
      @container_manager = container_manager
      @credentials = credentials
    end

    def deploy(tag: nil, host_filter: nil, service_filter: nil, skip_pull: false, &on_progress)
      hosts = resolve_hosts(host_filter)
      services = resolve_services(service_filter)
      image = @config.full_image(tag: tag)

      hosts.each do |host|
        host_services = services.select { |s| s.hosts.include?(host.name) }
        next if host_services.empty?

        executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)

        report(on_progress, host: host.name, step: :login, detail: @config.registry)
        registry_login(executor)

        unless skip_pull
          report(on_progress, host: host.name, step: :pull, detail: image)
          executor.run("docker pull #{image}")
        end

        report(on_progress, host: host.name, step: :upload_secrets)
        upload_secrets(executor, host.name)

        host_services.each do |service|
          each_replica(service) do |replica|
            name = service.container_name(@config.project, replica)

            report(on_progress, host: host.name, step: :stop, detail: name)
            @container_manager.stop(service: service, host: host, replica: replica)

            report(on_progress, host: host.name, step: :remove, detail: name)
            @container_manager.remove(service: service, host: host, replica: replica)

            report(on_progress, host: host.name, step: :start, detail: name)
            @container_manager.start(
              service: service, host: host, replica: replica,
              tag: tag, env_file_path: REMOTE_ENV_PATH
            )
          end
        end
      end
    end

    private

    def registry_login(executor)
      creds = @credentials.resolve
      return unless creds

      executor.run(
        "echo #{Shellwords.escape(creds[:password])} | docker login #{@config.registry} -u #{Shellwords.escape(creds[:username])} --password-stdin"
      )
    end

    def upload_secrets(executor, host_name)
      content = @env_builder.secrets_file_content(host_name: host_name)
      executor.run("mkdir -p ~/.dockaroo")
      executor.upload(content, REMOTE_ENV_PATH, mode: "0600") unless content.empty?
    end

    def resolve_hosts(host_filter)
      if host_filter
        host = @config.find_host(host_filter)
        raise ConfigError, "Host not found: #{host_filter}" unless host

        [host]
      else
        @config.hosts
      end
    end

    def resolve_services(service_filter)
      if service_filter
        service = @config.find_service(service_filter)
        raise ConfigError, "Service not found: #{service_filter}" unless service

        [service]
      else
        @config.services
      end
    end

    def each_replica(service)
      if service.replicated?
        (1..service.replicas).each { |i| yield i }
      else
        yield nil
      end
    end

    def report(callback, host:, step:, detail: nil)
      callback&.call(host: host, step: step, detail: detail)
    end
  end
end
