# frozen_string_literal: true

require "json"

module Dockaroo
  class ContainerManager
    def initialize(config:, env_builder:)
      @config = config
      @env_builder = env_builder
    end

    # Generate the full `docker run` command string
    def run_command(service:, host_name:, replica: nil, tag: nil, env_file_path: nil)
      name = service.container_name(@config.project, replica)
      parts = ["docker run --detach"]
      parts << "--name #{name}"
      parts << "--network #{service.network}" if service.network
      parts << "--restart #{service.restart}" if service.restart
      parts << "--env-file #{env_file_path}" if env_file_path

      @env_builder.env_flags(service: service, host_name: host_name, replica: replica).each do |flag|
        parts << "--env #{flag}"
      end

      service.volumes.each do |vol|
        parts << "--volume #{vol}"
      end

      if service.logging
        parts << "--log-driver json-file"
        parts << "--log-opt max-size=#{service.logging[:max_size]}" if service.logging[:max_size]
        parts << "--log-opt max-file=#{service.logging[:max_file]}" if service.logging[:max_file]
      end

      parts << @config.full_image(tag: tag)
      parts << service.cmd

      parts.join(" \\\n  ")
    end

    # Execute docker run on remote host
    def start(service:, host:, replica: nil, tag: nil, env_file_path: nil)
      cmd = run_command(service: service, host_name: host.name, replica: replica, tag: tag, env_file_path: env_file_path)
      executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)
      executor.run(cmd)
    end

    def stop(service:, host:, replica: nil, timeout: 10)
      name = service.container_name(@config.project, replica)
      executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)
      executor.run("docker stop --time #{timeout} #{name}")
    end

    def restart(service:, host:, replica: nil, tag: nil, env_file_path: nil, timeout: 10)
      stop(service: service, host: host, replica: replica, timeout: timeout)
      remove(service: service, host: host, replica: replica)
      start(service: service, host: host, replica: replica, tag: tag, env_file_path: env_file_path)
    end

    def remove(service:, host:, replica: nil)
      name = service.container_name(@config.project, replica)
      executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)
      executor.run("docker rm #{name}")
    end

    # Query container status on a host, returns array of hashes
    def status(host:)
      executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)
      result = executor.run("docker ps -a --format \"{{json .}}\" --filter \"name=^#{@config.project}-\"")
      return [] unless result.success?

      parse_docker_ps(result.stdout)
    end

    private

    def parse_docker_ps(output)
      output.lines.filter_map do |line|
        line = line.strip
        next if line.empty?

        data = JSON.parse(line)
        parse_container(data)
      rescue => e
        $stderr.puts "Warning: failed to parse container: #{e.class}: #{e.message}"
        nil
      end
    end

    def parse_container(data)
      name = data["Names"]
      project_prefix = "#{@config.project}-"

      return nil unless name&.start_with?(project_prefix)

      # Parse: {project}-{service}-{replica} or {project}-{service}
      remainder = name.delete_prefix(project_prefix)
      parts = remainder.rpartition("-")

      if parts[1] == "-" && parts[2].match?(/\A\d+\z/)
        service_name = parts[0]
        replica = parts[2].to_i
      else
        service_name = remainder
        replica = nil
      end

      # Extract image tag
      image = data["Image"] || ""
      image_tag = image.split(":").last

      {
        name: name,
        service: service_name,
        replica: replica,
        status: data["Status"] || "",
        state: data["State"] || "",
        image: image,
        image_tag: image_tag,
        created: data["CreatedAt"] || "",
        running_for: data["RunningFor"] || ""
      }
    end
  end
end
