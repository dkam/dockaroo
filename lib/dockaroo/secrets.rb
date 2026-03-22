# frozen_string_literal: true

module Dockaroo
  class Secrets
    def initialize(base_dir: ".dockaroo")
      @base_dir = base_dir
    end

    def load_for_host(host_name)
      base = @base_secrets ||= load_file(File.join(@base_dir, "secrets"))
      overrides = load_file(File.join(@base_dir, "secrets.#{host_name}"))
      base.merge(overrides)
    end

    private

    def load_file(path)
      return {} unless File.exist?(path)

      env = {}
      File.readlines(path).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?("#")

        line = line.delete_prefix("export ")
        key, value = line.split("=", 2)
        next unless key && value

        key = key.strip
        value = value.strip
        value = unquote(value)
        env[key] = value
      end
      env
    end

    def unquote(value)
      if (value.start_with?('"') && value.end_with?('"')) ||
         (value.start_with?("'") && value.end_with?("'"))
        value[1..-2]
      else
        value
      end
    end
  end
end
