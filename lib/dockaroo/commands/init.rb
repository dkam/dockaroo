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

      def self.run(args, config_path: ".dockaroo.yml")
        if File.exist?(config_path)
          $stderr.puts "#{config_path} already exists"
          exit 1
        end

        File.write(config_path, TEMPLATE)
        puts "Created #{config_path}"
      end
    end
  end
end
