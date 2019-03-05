module Proxy
  module Ansible
    # Calls for the smart-proxy API to register the plugin
    class Plugin < Proxy::Plugin
      http_rackup_path File.expand_path('http_config.ru',
                                        File.expand_path('../', __FILE__))
      https_rackup_path File.expand_path('http_config.ru',
                                         File.expand_path('../', __FILE__))

      settings_file 'ansible.yml'
      plugin :ansible, Proxy::Ansible::VERSION

      after_activation do
        begin
          require 'smart_proxy_dynflow_core'
          require 'foreman_ansible_core'
          ForemanAnsibleCore.initialize_settings(Proxy::Ansible::Plugin.settings.to_h)
        rescue LoadError => _
          # Dynflow core is not available in the proxy, will be handled
          # by standalone Dynflow core
        end
      end
    end
  end
end
