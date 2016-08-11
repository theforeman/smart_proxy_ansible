require 'json'
require 'smart_proxy_ansible_core/foreman_request'

module Proxy
  module Ansible
    module Core
      class EventsHandler

        class Importer
          def import(event)
            ansible_facts = @event.data.fetch('data', {}).fetch('ansible_facts', {})
            host_name = @event.data.fetch("host", nil)
            module_name = @event.data.fetch("data", {}).fetch("invocation", {}).fetch("module_name", nil)

            if module_name == "setup"
              facts = { :operatingsystem => ansible_facts['ansible_os_family'],
                        :operatingsystemrelease => ansible_facts['ansible_distribution_version'],
                        :architecture => ansible_facts['ansible_architecture'],
                        :interfaces => ansible_facts['ansible_interfaces'].join(',')}

              ansible_facts['ansible_interfaces'].each do |device|
                device_facts = ansible_facts.fetch("ansible_#{device}", {})
                ipv4_facts = device_facts.fetch('ipv4', {})
                facts["ipaddress_#{device}"] = ipv4_facts["address"]
                facts["netmask_#{device}"] = ipv4_facts["netmask"]
                facts["macaddress_#{device}"] = device_facts["macaddress"]
              end

              ForemanRequest.new.post_facts(JSON.dump({ :name => host_name,
                                                        :facts => facts }))
            end
          end
        end

        class Execution
          def initialize(execution_dir)
            @execution_dir = execution_dir
            load_status
          end

          def process
            unprocessed_files.each do |file|
              yield Command::Update::EventData.new(JSON.load(File.read(file)))
              @status["last_processed_file"] = file
              save_status
            end
          end

          def status_file
            File.join(@execution_dir, 'processing_status.json')
          end

          def load_status
            @status = if File.exist?(status_file)
                        JSON.load(File.read(status_file))
                      else
                        {}
                      end
          end

          def save_status
            File.write(status_file, JSON.dump(@status))
          end

          def event_files
            @event_files ||= (Dir.glob(File.join(@execution_dir, "*.json")).to_a - [status_file]).sort
          end

          def unprocessed_files
            if last_processed_file
              event_files.drop_while { |file| file != last_processed_file }.drop(1)
            else
              event_files
            end
          end

          def last_processed_file
            @status["last_processed_file"]
          end
        end

        def initialize
          @base_dir = '/tmp/ansible/events'
        end

        def process
          importer = Importer.new
          executions.each do |e|
            e.process { |event| importer.import(event)}
          end
        end

        def executions
          Dir.glob(File.join(@base_dir, "*")).map do |file|
            Execution.new(file)
          end
        end
      end
    end
  end
end
