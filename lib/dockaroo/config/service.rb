# frozen_string_literal: true

module Dockaroo
  class Config
    Service = Data.define(:name, :image, :cmd, :hosts, :replicas, :network, :restart, :environment, :volumes, :ports, :logging, :remote_dir) do
      def initialize(name:, image: nil, cmd: nil, hosts: [], replicas: 1, network: nil, restart: nil, environment: {}, volumes: [], ports: [], logging: nil, remote_dir: "~")
        super(
          name: name,
          image: image,
          cmd: cmd,
          hosts: hosts,
          replicas: replicas,
          network: network,
          restart: restart,
          environment: environment,
          volumes: volumes,
          ports: ports,
          logging: logging,
          remote_dir: remote_dir
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

      # Replace the tag portion of the image string
      def image_with_tag(tag)
        base, _, _old_tag = image.rpartition(":")
        if base.empty?
          "#{image}:#{tag}"
        else
          "#{base}:#{tag}"
        end
      end
    end
  end
end
