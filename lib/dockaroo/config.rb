# frozen_string_literal: true

require "yaml"
require_relative "config/host"
require_relative "config/service"

module Dockaroo
  class Config
    attr_reader :path, :hosts, :services

    def self.load(path = ".dockaroo.yml")
      raise ConfigError, "Config file not found: #{path}" unless File.exist?(path)

      raw = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      new(raw: raw, path: path)
    end

    def self.load_or_create(path = ".dockaroo.yml")
      load(path)
    rescue ConfigError
      new(path: path)
    end

    def self.exists?(path = ".dockaroo.yml")
      File.exist?(path)
    end

    def initialize(raw: {}, path: ".dockaroo.yml")
      @raw = raw
      @path = path
      @hosts = parse_hosts
      @services = parse_services
    end

    def project
      @raw["project"]
    end

    def defaults
      @raw["defaults"] || {}
    end

    def default_image
      defaults["image"]
    end

    def find_service(name)
      @services.find { |s| s.name == name }
    end

    def save
      @raw["hosts"] = hosts_to_hash
      File.write(@path, YAML.dump(@raw))
    end

    def add_host(name, user: nil, port: 22)
      raise ConfigError, "Host already exists: #{name}" if find_host(name)

      @hosts << Host.new(name: name, user: user, port: port)
    end

    def remove_host(name)
      host = find_host(name)
      raise ConfigError, "Host not found: #{name}" unless host

      @hosts.delete(host)
    end

    def update_host(name, user: nil, port: nil)
      host = find_host(name)
      raise ConfigError, "Host not found: #{name}" unless host

      idx = @hosts.index(host)
      @hosts[idx] = Host.new(
        name: name,
        user: user || host.user,
        port: port || host.port
      )
    end

    def find_host(name)
      @hosts.find { |h| h.name == name }
    end

    private

    def parse_hosts
      hosts_hash = @raw["hosts"] || {}
      hosts_hash.map do |name, settings|
        settings ||= {}
        Host.new(
          name: name,
          user: settings["user"],
          port: settings["port"] || 22
        )
      end
    end

    def parse_services
      services_hash = @raw["services"] || {}
      defs = defaults

      services_hash.map do |name, settings|
        settings ||= {}
        merged = merge_defaults(settings, defs)

        logging = if merged["logging"]
                    { max_size: merged["logging"]["max_size"], max_file: merged["logging"]["max_file"] }
                  end

        Service.new(
          name: name,
          image: merged["image"],
          cmd: merged["cmd"],
          hosts: Array(merged["hosts"]),
          replicas: merged["replicas"] || 1,
          network: merged["network"],
          restart: merged["restart"],
          environment: merged["environment"] || {},
          volumes: Array(merged["volumes"]),
          ports: Array(merged["ports"]),
          logging: logging,
          remote_dir: merged["remote_dir"] || "~"
        )
      end
    end

    def merge_defaults(service_hash, defs)
      merged = defs.dup

      service_hash.each do |key, value|
        case key
        when "environment"
          # Merge: defaults env + service env (service wins on conflict)
          merged["environment"] = (merged["environment"] || {}).merge(value || {})
        when "volumes"
          # Merge: combined list
          merged["volumes"] = Array(merged["volumes"]) + Array(value)
        else
          merged[key] = value
        end
      end

      merged
    end

    def hosts_to_hash
      @hosts.each_with_object({}) do |host, hash|
        settings = {}
        settings["user"] = host.user if host.user
        settings["port"] = host.port if host.port != 22
        hash[host.name] = settings.empty? ? nil : settings
      end
    end
  end
end
