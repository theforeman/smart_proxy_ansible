module Proxy::Ansible
  module Command
    class Update
      attr_reader :buffer, :exit_status

      def initialize(buffer, exit_status = nil)
        @buffer = buffer
        @exit_status = exit_status
      end

      def buffer_to_hash
        buffer.map(&:to_hash)
      end

      def self.encode_exception(description, exception)
        ret = [DebugData.new("#{description}\n#{exception.class} #{exception.message}")]
        return ret
      end

      class Data
        attr_reader :data, :timestamp

        def initialize(data, timestamp = Time.now)
          @data = data
          @timestamp = timestamp
        end

        def data_type
          raise NotImplemented
        end

        def to_hash
          { :output_type => data_type,
            :output => data,
            :timestamp => timestamp.to_f }
        end
      end

      class EventData < Data
        def initialize(*args)
          super
          @timestamp = Time.at(@data['timestamp'].to_f) if @data['timestamp']
        end
        def data_type
          :event
        end
      end

      class StdoutData < Data

        def initialize(data, timestamp = Time.now)
          sanitized_data = data.lines.map do |line|
            line.chars.select(&:ascii_only?).join.rstrip
          end.reject(&:empty?)
          super(sanitized_data, timestamp)
        end

        def data_type
          :stdout
        end
      end

      class StderrData < Data
        def data_type
          :stderr
        end
      end

      class DebugData < Data
        def data_type
          :debug
        end
      end

      class StatusData < Data
        def data_type
          :status
        end
      end
    end

    module Playbook

      class PlayRoles < ::Dynflow::Action

        def plan(input)
          input[:inventory] = inventory(input)
          plan_action ::Proxy::Ansible::Command::Playbook::Action, input
        end

        def inventory(input)
          input['inventory'].map do |fqdn, roles|
            role_string = roles.map { |role| "'#{role}'" }.join(',')
            "#{fqdn} foreman_ansible_roles=[#{role_string}]"
          end.join("\n")
        end

      end

      class Request
        attr_reader :id, :inventory, :playbook, :suspended_action

        def initialize(data)
          validate!(data)

          @id = data[:id]
          @inventory = data[:inventory]
          @playbook = data[:playbook]
          @suspended_action = data[:suspended_action]
        end

        def validate!(data)
          required_fields = [:id, :suspended_action]
          missing_fields = required_fields.find_all { |f| !data[f] }
          raise ArgumentError, "Missing fields: #{missing_fields}" unless missing_fields.empty?
        end

        def suspended_action
          @suspended_action
        end
      end

      class Action < ::Dynflow::Action
        include Dynflow::Action::Cancellable
        include ::SmartProxyDynflowCore::Callback::PlanHelper

        def plan(input)
          if callback = input['callback']
            input[:task_id] = callback['task_id']
          else
            input[:task_id] ||= SecureRandom.uuid
          end
          plan_with_callback(input)
        end

        def run(event = nil)
          case event
            when nil
              init_run
            when Update
              process_update(event)
            when Dynflow::Action::Cancellable::Cancel
              kill_run
            when Dynflow::Action::Skip
              # do nothing
            else
              raise "Unexpected event #{event.inspect}"
          end
        rescue => e
          action_logger.error(e)
          process_update(Update.new(Update.encode_exception("Proxy error", e)))
        end

        def finalize
          # To mark the task as a whole as failed
          error! "Script execution failed" if failed_run?
        end

        def rescue_strategy_for_self
          Dynflow::Action::Rescue::Skip
        end

        def request
          @request ||= Request.new(:id => input[:task_id],
                                   :inventory => input[:inventory],
                                   :playbook => input[:playbook],
                                   :suspended_action => suspended_action)
        end

        def init_run
          output[:result] = []
          Proxy::Ansible.dispatcher.tell([:initialize_command, request])
          suspend
        end

        def kill_run
          Proxy::Ansible.dispatcher.tell([:kill, request])
          suspend
        end

        def finish_run(update)
          output[:exit_status] = update.exit_status
        end

        def process_update(update)
          output[:result].concat(update.buffer_to_hash)
          if update.exit_status
            finish_run(update)
          else
            suspend
          end
        end

        def failed_run?
          output[:exit_status] != 0
        end
      end
    end
  end
end
