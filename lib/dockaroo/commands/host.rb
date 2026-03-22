# frozen_string_literal: true

require "optparse"

module Dockaroo
  module Commands
    class Host
      def self.run(args, config_path: ".dockaroo.yml")
        new(args, config_path: config_path).run
      end

      def initialize(args, config_path: ".dockaroo.yml")
        @args = args
        @config_path = config_path
      end

      def run
        subcommand = @args.shift

        case subcommand
        when "add"
          add
        when "remove"
          remove
        when "list"
          list
        when "test"
          test_connection
        else
          $stderr.puts host_usage
          exit 1
        end
      end

      private

      def add
        user = nil
        port = 22

        parser = OptionParser.new do |opts|
          opts.on("--user USER", "SSH user") { |v| user = v }
          opts.on("--port PORT", Integer, "SSH port") { |v| port = v }
        end
        parser.parse!(@args)

        name = @args.shift
        unless name
          $stderr.puts "Usage: dockaroo host add <name> [--user USER] [--port PORT]"
          exit 1
        end

        config = load_or_create_config
        config.add_host(name, user: user, port: port)
        config.save
        puts "Added host: #{name}"
      rescue Dockaroo::ConfigError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      def remove
        name = @args.shift
        unless name
          $stderr.puts "Usage: dockaroo host remove <name>"
          exit 1
        end

        config = load_config
        config.remove_host(name)
        config.save
        puts "Removed host: #{name}"
      rescue Dockaroo::ConfigError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      def list
        config = load_or_create_config
        if config.hosts.empty?
          puts "No hosts configured. Add one with: dockaroo host add <name> --user <user>"
          return
        end

        puts format("%-20s %-15s %s", "HOST", "USER", "PORT")
        puts "-" * 40
        config.hosts.each do |host|
          puts format("%-20s %-15s %s", host.name, host.user || "(current)", host.port)
        end
      rescue Dockaroo::ConfigError => e
        $stderr.puts "Error: #{e.message}"
        exit 1
      end

      def test_connection
        name = @args.shift
        unless name
          $stderr.puts "Usage: dockaroo host test <name>"
          exit 1
        end

        config = load_config
        host = config.find_host(name)
        unless host
          $stderr.puts "Error: Host not found: #{name}"
          exit 1
        end

        print "Testing SSH connection to #{name}... "
        executor = SSHExecutor.new(host: host.name, user: host.user, port: host.port)
        result = executor.run("hostname")
        executor.close
        puts "OK (#{result.stdout})"
      rescue Dockaroo::SSHError => e
        puts "FAILED"
        $stderr.puts "  #{e.message}"
        exit 1
      end

      def load_config
        Config.load(@config_path)
      end

      def load_or_create_config
        if Config.exists?(@config_path)
          Config.load(@config_path)
        else
          Config.new(path: @config_path)
        end
      end

      def host_usage
        <<~USAGE
          Usage: dockaroo host <subcommand> [options]

          Subcommands:
            add <name> [--user USER] [--port PORT]   Add a host
            remove <name>                             Remove a host
            list                                      List all hosts
            test <name>                               Test SSH connection
        USAGE
      end
    end
  end
end
