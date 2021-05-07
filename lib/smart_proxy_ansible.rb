require 'smart_proxy_dynflow'

module Proxy
  # Basic requires for this plugin
  module Ansible
    require 'smart_proxy_ansible/version'
    require 'smart_proxy_ansible/plugin'
    require 'smart_proxy_ansible/roles_reader'
    require 'smart_proxy_ansible/variables_extractor'

    require 'foreman_tasks_core'
    require 'smart_proxy_ansible/task_launcher/ansible_runner'
    require 'smart_proxy_ansible/task_launcher/playbook'
    require 'smart_proxy_ansible/actions'
    require 'smart_proxy_ansible/remote_execution_core/ansible_runner'
    require 'smart_proxy_ansible/runner/ansible_runner'
    require 'smart_proxy_ansible/runner/command_creator'
    require 'smart_proxy_ansible/runner/playbook'
  end
end
