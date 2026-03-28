# frozen_string_literal: true

require "shellwords"

module Dockaroo
  class Deployer
    REMOTE_ENV_DIR = ".dockaroo"
    REMOTE_ENV_FILENAME = "env"

    def initialize(config:, env_builder:, container_manager:, credentials:)
      @config = config
      @env_builder = env_builder
      @container_manager = container_manager
      @credentials = credentials
    end

    def deploy(tag: nil, host_filter: nil, service_filter: nil, skip_pull: false, &on_progress)
      hosts = resolve_hosts(host_filter)
      services = resolve_services(service_filter)

      hosts.each do |host|
        host_services = services.select { |s| s.hosts.include?(host.name) }
        next if host_services.empty?

        executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)

        images_needed = host_services.map { |s| effective_image(s, tag) }.uniq
        registries = images_needed.filter_map { |img| extract_registry(img) }.uniq

        registries.each do |reg|
          report(on_progress, host: host.name, step: :login, detail: reg)
          registry_login(executor, reg)
        end

        unless skip_pull
          images_needed.each do |img|
            report(on_progress, host: host.name, step: :pull, detail: img)
            executor.run("docker pull #{img}")
          end
        end

        remote_home = executor.run("echo $HOME").stdout.strip
        env_dir = "#{remote_home}/#{REMOTE_ENV_DIR}"
        env_file_path = "#{env_dir}/#{REMOTE_ENV_FILENAME}"

        report(on_progress, host: host.name, step: :upload_secrets)
        upload_secrets(executor, host.name, env_dir: env_dir, env_file_path: env_file_path)

        host_services.map(&:remote_dir).uniq.each do |dir|
          executor.run("mkdir -p #{dir}")
        end

        host_services.each do |service|
          service_tag = tag if tag && uses_default_image?(service)

          each_replica(service) do |replica|
            name = service.container_name(@config.project, replica)

            report(on_progress, host: host.name, step: :stop, detail: name)
            @container_manager.stop(service: service, host: host, replica: replica)

            report(on_progress, host: host.name, step: :remove, detail: name)
            @container_manager.remove(service: service, host: host, replica: replica)

            report(on_progress, host: host.name, step: :start, detail: name)
            @container_manager.start(
              service: service, host: host, replica: replica,
              tag: service_tag, env_file_path: env_file_path
            )
          end
        end
      end
    end

    private

    def registry_login(executor, registry)
      creds = @credentials.resolve
      return unless creds

      executor.run(
        "echo #{Shellwords.escape(creds[:password])} | docker login #{registry} -u #{Shellwords.escape(creds[:username])} --password-stdin"
      )
    end

    def effective_image(service, tag)
      if tag && uses_default_image?(service)
        service.image_with_tag(tag)
      else
        service.image
      end
    end

    def uses_default_image?(service)
      default = @config.default_image
      return false unless default

      service.image.rpartition(":").first == default.rpartition(":").first
    end

    def extract_registry(image)
      parts = image.split("/")
      parts.size > 1 && parts.first.include?(".") ? parts.first : nil
    end

    def upload_secrets(executor, host_name, env_dir:, env_file_path:)
      content = @env_builder.secrets_file_content(host_name: host_name)
      executor.run("mkdir -p #{env_dir}")
      executor.upload(content, env_file_path, mode: "0600")
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
