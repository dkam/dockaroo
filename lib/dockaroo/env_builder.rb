# frozen_string_literal: true

module Dockaroo
  class EnvBuilder
    def initialize(config:, secrets:)
      @config = config
      @secrets = secrets
    end

    # Returns string in dotenv format for upload to host as --env-file
    def secrets_file_content(host_name:)
      vars = @secrets.load_for_host(host_name)
      vars.map { |k, v| "#{k}=#{v}" }.join("\n")
    end

    # Returns array of "KEY=VALUE" strings for --env flags
    def env_flags(service:, host_name:, replica: nil)
      vars = {}

      # Non-secret defaults from YAML
      (@config.defaults["environment"] || {}).each { |k, v| vars[k] = v.to_s }

      # Per-service overrides
      service.environment.each { |k, v| vars[k] = v.to_s }

      # Auto-injected
      vars["DOCKAROO_PROJECT"] = @config.project.to_s
      vars["DOCKAROO_SERVICE"] = service.name.to_s
      vars["DOCKAROO_HOST"] = host_name.to_s
      vars["DOCKAROO_INSTANCE"] = replica.to_s if replica && service.replicated?

      vars.map { |k, v| "#{k}=#{v}" }
    end
  end
end
