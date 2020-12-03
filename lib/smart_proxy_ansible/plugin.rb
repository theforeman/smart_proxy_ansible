module Proxy
  module Ansible
    # Calls for the smart-proxy API to register the plugin
    class Plugin < Proxy::Plugin
      rackup_path File.expand_path('http_config.ru', __dir__)
      settings_file 'ansible.yml'
      plugin :ansible, Proxy::Ansible::VERSION
      default_settings ansible_dir: Dir.home
      # :working_dir => nil

      after_activation do
        require 'smart_proxy_dynflow'
        require 'smart_proxy_dynflow/continuous_output'
        require 'smart_proxy_ansible/task_launcher/ansible_runner'
        require 'smart_proxy_ansible/task_launcher/playbook'
        require 'smart_proxy_ansible/actions'
        require 'smart_proxy_ansible/remote_execution_core/ansible_runner'
        require 'smart_proxy_ansible/runner/ansible_runner'
        require 'smart_proxy_ansible/runner/command_creator'
        require 'smart_proxy_ansible/runner/playbook'

        Proxy::Dynflow::TaskLauncherRegistry.register('ansible-runner',
          TaskLauncher::AnsibleRunner)
        Proxy::Dynflow::TaskLauncherRegistry.register('ansible-playbook',
          TaskLauncher::Playbook)
      end
    end
  end
end
