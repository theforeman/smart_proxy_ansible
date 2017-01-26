require 'smart_proxy_ansible_core/session'

module Proxy::Ansible::Core
  # Service that handles running external commands for Actions::Command
  # Dynflow action. It runs just one (actor) thread for all the commands
  # running in the system and updates the Dynflow actions periodically.
  class Dispatcher < ::Dynflow::Actor
    # command comming from action

    def initialize(options = {})
      @clock                   = options[:clock] || Dynflow::Clock.spawn('proxy-dispatcher-clock')
      @logger                  = options[:logger] || Logger.new($stderr)

      @session_args = { :logger => @logger,
                        :clock => @clock,
                        :connector_class => options[:connector_class] || Connector,
                        :refresh_interval => options[:refresh_interval] || 1 }

      @sessions = {}
    end

    def initialize_command(request)
      @logger.debug("initalizing command [#{request}]")
      open_session(request)
    rescue => exception
      handle_command_exception(request, exception)
    end

    def kill(request)
      @logger.debug("killing command [#{request}]")
      session = @sessions[request.id]
      session.tell(:kill) if session
    rescue => exception
      handle_command_exception(request, exception, false)
    end

    def finish_command(request)
      close_session(request)
    rescue => exception
      handle_command_exception(request, exception)
    end

    private

    def handle_command_exception(request, exception, fatal = true)
      @logger.error("error while dispatching request #{request} to session:"\
                    "#{exception.class} #{exception.message}:\n #{exception.backtrace.join("\n")}")
      command_data = CommandUpdate.encode_exception("Failed to dispatch the command", exception, fatal)
      request.suspended_action << CommandUpdate.new(command_data)
      close_session(request) if fatal
    end

    def open_session(request)
      raise "Session already opened for request #{request}" if @sessions[request.id]
      options = { :name => "proxy-ansible-session-#{request.id}",
                  :args => [request, @session_args],
                  :supervise => true }
      @sessions[request.id] = Proxy::Ansible::Core::Session.spawn(options)
    end

    def close_session(request)
      session = @sessions.delete(request.id)
      return unless session
      @logger.debug("closing session for command [#{request}], #{@sessions.size} session(s) left ")
      session.tell([:start_termination, Concurrent.future])
    end
  end
end

