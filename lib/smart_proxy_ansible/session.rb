require 'io/wait'
require 'pty'

module Proxy::Ansible
  # Service that handles running external commands for Actions::Command
  # Dynflow action. It runs just one (actor) thread for all the commands
  # running in the system and updates the Dynflow actions periodically.
  class Session < ::Dynflow::Actor
    attr_reader :request

    def initialize(request, options = {})
      @clock = options[:clock] || Dynflow::Clock.spawn('proxy-dispatcher-clock')
      @logger = options[:logger] || Logger.new($stderr)
      @working_dir = File.expand_path(options[:working_dir] || Plugin.settings.ansible_working_dir)
      @refresh_interval = options[:refresh_interval] || 1
      @request = request

      @buffer = []
      @refresh_planned = false

      reference.tell(:initialize_command)
    end

    def initialize_command
      write_inventory
      write_playbook
      @logger.debug("initalizing command [#{@request}]") #
      Dir.chdir(@working_dir) do
        @command_out, @command_in, @command_pid = PTY.spawn(*command)
      end
    rescue => e
      @logger.error("error while initalizing command #{e.class} #{e.message}:\n #{e.backtrace.join("\n")}")
      @buffer.concat(Command::Update.encode_exception("Error initializing command #{@request}", e))
      refresh
    ensure
      plan_next_refresh
    end

    def command
      command = [{ 'ANSIBLE_EVENTS_DIR' => events_dir }, "ansible-playbook"]
      command.concat(["-i", inventory_file]) if @request.inventory
      command << playbook_file
      command
    end

    def refresh
      @logger.debug("refreshing command [#{@request}]")
      try_to_read
      new_data = @buffer

      @events_handler = EventsHandler::Execution.new(events_dir).process do |event|
        new_data << event
      end

      @buffer = []
      update = Command::Update.new(new_data, @exit_status)
      @request.suspended_action << update
    rescue => e
      @logger.error("#{e.message}\n #{e.backtrace.join("\n")}")
      @buffer.concat(Command::Update.encode_exception("Failed to refresh the connector", e))
    ensure
      @refresh_planned = false
      plan_next_refresh
    end

    def try_to_read
      return if @command_out.nil?
      ready_outputs, * = IO.select([@command_out], nil, nil, 0.1)
      if ready_outputs
        if @command_out.nread > 0
          lines = @command_out.read_nonblock(@command_out.nread)
        else
          @command_out.close
          @command_in.close
          Process.wait(@command_pid)
          @command_out = nil
          @command_in = nil
          @command_pid = nil
          @exit_status = $?.exitstatus
        end
        @buffer << Command::Update::StdoutData.new(lines) if lines && !lines.empty?
      end
    end

    private

    def write_inventory
      ensure_directory(File.dirname(inventory_file))
      File.write(inventory_file, @request.inventory)
    end

    def write_playbook
      ensure_directory(File.dirname(playbook_file))
      File.write(playbook_file, @request.playbook)
    end

    def inventory_file
      File.join(@working_dir, "foreman-inventories", @request.id)
    end

    def playbook_file
      File.join(@working_dir, "foreman-playbook-#{@request.id}.yml")
    end

    def events_dir
      File.join(@working_dir, "events", "#{@request.id}")
    end

    def ensure_directory(path)
      if File.exist?(path)
        raise "#{path} expected to be a directory" unless File.directory?(path)
      else
        FileUtils.mkdir_p(path)
      end
      return path
    end

    def plan_next_refresh
      if @command_out && !@refresh_planned
        @logger.debug("planning to refresh")
        @clock.ping(reference, Time.now + @refresh_interval, :refresh)
        @refresh_planned = true
      end
    end
  end
end
