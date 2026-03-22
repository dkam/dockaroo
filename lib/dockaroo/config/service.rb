# frozen_string_literal: true

module Dockaroo
  class Config
    Service = Data.define(:name, :cmd, :hosts, :replicas, :network, :restart, :environment, :volumes, :logging) do
      def initialize(name:, cmd:, hosts:, replicas: 1, network: nil, restart: nil, environment: {}, volumes: [], logging: nil)
        super(
          name: name,
          cmd: cmd,
          hosts: hosts,
          replicas: replicas,
          network: network,
          restart: restart,
          environment: environment,
          volumes: volumes,
          logging: logging
        )
      end

      def replicated?
        replicas > 1
      end

      def container_name(project, replica = nil)
        if replicated? && replica
          "#{project}-#{name}-#{replica}"
        else
          "#{project}-#{name}"
        end
      end
    end
  end
end
