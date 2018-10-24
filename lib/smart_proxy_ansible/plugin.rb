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
    end
  end
end
