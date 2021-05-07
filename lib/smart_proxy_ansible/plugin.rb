module Proxy
  module Ansible
    # Calls for the smart-proxy API to register the plugin
    class Plugin < Proxy::Plugin
      rackup_path File.expand_path('http_config.ru', __dir__)
      settings_file 'ansible.yml'
      plugin :ansible, Proxy::Ansible::VERSION
      default_settings :ansible_dir => Dir.home
                       # :working_dir => nil

      after_activation do
        SmartProxyDynflowCore::TaskLauncherRegistry.register('ansible-runner',
          TaskLauncher::AnsibleRunner)
        SmartProxyDynflowCore::TaskLauncherRegistry.register('ansible-playbook',
          TaskLauncher::Playbook)
      end
    end
  end
end
