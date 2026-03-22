# frozen_string_literal: true

module Dockaroo
  class Credentials
    def initialize(secrets:)
      @secrets = secrets
    end

    # Returns {username:, password:} or nil
    def resolve
      from_env || from_secrets || from_prompt
    end

    private

    def from_env
      username = ENV["DOCKAROO_REGISTRY_USERNAME"]
      password = ENV["DOCKAROO_REGISTRY_PASSWORD"]
      return nil unless username && password

      { username: username, password: password }
    end

    def from_secrets
      vars = @secrets.load_base
      username = vars["DOCKAROO_REGISTRY_USERNAME"]
      password = vars["DOCKAROO_REGISTRY_PASSWORD"]
      return nil unless username && password

      { username: username, password: password }
    end

    def from_prompt
      return nil unless $stdin.tty?

      $stderr.print "Registry username: "
      username = $stdin.gets&.chomp
      return nil if username.nil? || username.empty?

      $stderr.print "Registry password: "
      password = $stdin.gets&.chomp
      return nil if password.nil? || password.empty?

      { username: username, password: password }
    end
  end
end
