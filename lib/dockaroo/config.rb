# frozen_string_literal: true

require "yaml"
require_relative "config/host"

module Dockaroo
  class Config
    attr_reader :path, :hosts

    def self.load(path = ".dockaroo.yml")
      raise ConfigError, "Config file not found: #{path}" unless File.exist?(path)

      raw = YAML.safe_load_file(path, permitted_classes: [Symbol]) || {}
      new(raw: raw, path: path)
    end

    def self.exists?(path = ".dockaroo.yml")
      File.exist?(path)
    end

    def initialize(raw: {}, path: ".dockaroo.yml")
      @raw = raw
      @path = path
      @hosts = parse_hosts
    end

    def project
      @raw["project"]
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
