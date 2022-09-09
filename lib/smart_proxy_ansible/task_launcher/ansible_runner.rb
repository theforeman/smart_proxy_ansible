require 'fileutils'
require 'smart_proxy_dynflow/task_launcher/abstract'
require 'smart_proxy_dynflow/task_launcher/batch'
require 'smart_proxy_dynflow/task_launcher/group'
require 'smart_proxy_ansible/runner/ansible_runner'

module Proxy::Ansible
  module TaskLauncher
    class AnsibleRunner < Proxy::Dynflow::TaskLauncher::AbstractGroup
      def runner_input(input)
        super(input).reduce({}) do |acc, (_id, data)|
          acc.merge(data[:input]['action_input']['name'] => data)
        end
      end

      def operation
        'ansible-runner'
      end

      def self.runner_class
        Runner::AnsibleRunner
      end

      # Discard everything apart from hostname to be able to tell the actions
      # apart when debugging
      def transform_input(input)
        action_input = super['action_input']
        { 'action_input' => { 'name' => action_input['name'], :task_id => action_input[:task_id], :runner_id => action_input[:runner_id] } }
      end
    end
  end
end
