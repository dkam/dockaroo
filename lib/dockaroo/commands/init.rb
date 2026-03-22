# frozen_string_literal: true

module Dockaroo
  module Commands
    class Init
      TEMPLATE = <<~YAML
        # .dockaroo.yml
        project: myapp
        registry: registry.example.com
        image: myorg/myapp
        tag: latest

        defaults:
          network: host
          restart: on-failure
          logging:
            max_size: 50m
            max_file: 5

        hosts:
          # web01:
          #   user: deploy

        services:
          # worker:
          #   cmd: bundle exec sidekiq
          #   hosts: [web01]
          #   replicas: 2
      YAML

      SECRETS_TEMPLATE = <<~SECRETS
        # .dockaroo/secrets — shared secrets for all hosts
        # Uploaded to each host at deploy time. Use dotenv format: KEY=value
        #
        # DATABASE_URL=postgres://user:password@db:5432/myapp
        # REDIS_URL=redis://redis.tailscale:6379
        # SECRET_KEY_BASE=your-secret-key-here
      SECRETS

      SECRETS_GITIGNORE = <<~GITIGNORE
        secrets*
      GITIGNORE

      def self.run(args, config_path: ".dockaroo.yml")
        if File.exist?(config_path)
          $stderr.puts "#{config_path} already exists"
          exit 1
        end

        File.write(config_path, TEMPLATE)
        puts "Created #{config_path}"

        secrets_dir = ".dockaroo"
        Dir.mkdir(secrets_dir) unless Dir.exist?(secrets_dir)

        secrets_path = File.join(secrets_dir, "secrets")
        unless File.exist?(secrets_path)
          File.write(secrets_path, SECRETS_TEMPLATE)
          puts "Created #{secrets_path}"
        end

        gitignore_path = File.join(secrets_dir, ".gitignore")
        unless File.exist?(gitignore_path)
          File.write(gitignore_path, SECRETS_GITIGNORE)
        end
      end
    end
  end
end
