# frozen_string_literal: true

module Dockaroo
  class CLI
    COMMANDS = %w[status deploy logs stop start restart scale check host init].freeze

    def self.start(args)
      new(args).run
    end

    def initialize(args)
      @args = args
    end

    def run
      case @args.first
      when "--version", "-v"
        puts "dockaroo #{VERSION}"
      when nil
        puts "Dockaroo TUI — coming soon"
      when *COMMANDS
        dispatch(@args.first, @args[1..])
      else
        $stderr.puts usage
        exit 1
      end
    end

    private

    def dispatch(command, args)
      case command
      when "host"
        Commands::Host.run(args)
      when "init"
        Commands::Init.run(args)
      else
        $stderr.puts "dockaroo #{command}: not yet implemented"
        exit 1
      end
    end

    def usage
      <<~USAGE
        Usage: dockaroo [command] [options]

        Commands:
          status     Show container status across hosts
          deploy     Deploy services to hosts
          logs       Tail container logs
          stop       Stop a service
          start      Start a service
          restart    Restart a service
          scale      Scale service replicas
          check      Check host prerequisites
          host       Manage hosts
          init       Generate .dockaroo.yml

        Options:
          --version, -v    Show version
          --help, -h       Show this help
      USAGE
    end
  end
end
