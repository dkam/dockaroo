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
        require "bubbletea"
        require "lipgloss"
        require "bubbles"
        require_relative "tui/messages"
        require_relative "tui/screens/hosts"
        require_relative "tui/screens/host_form"
        require_relative "tui/app"
        app = TUI::App.new
        Bubbletea.run(app, alt_screen: true)
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
      when "check"
        Commands::Check.run(args)
      when "status"
        Commands::Status.run(args)
      when "start"
        Commands::Start.run(args)
      when "stop"
        Commands::Stop.run(args)
      when "restart"
        Commands::Restart.run(args)
      when "deploy"
        Commands::Deploy.run(args)
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
