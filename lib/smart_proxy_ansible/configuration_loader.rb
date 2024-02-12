module Proxy::Ansible
  class ConfigurationLoader
    def load_classes
      require 'smart_proxy_dynflow'
      require 'smart_proxy_dynflow/continuous_output'
      require 'smart_proxy_ansible/task_launcher/ansible_runner'
      require 'smart_proxy_ansible/artifacts_processor'
      require 'smart_proxy_ansible/runner/ansible_runner'

      Proxy::Dynflow::TaskLauncherRegistry.register('ansible-runner',
                                                    TaskLauncher::AnsibleRunner)
    end
  end
end
