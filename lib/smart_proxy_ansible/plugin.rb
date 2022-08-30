module Proxy
  module Ansible
    # Calls for the smart-proxy API to register the plugin
    class Plugin < Proxy::Plugin
      rackup_path File.expand_path('http_config.ru', __dir__)
      settings_file 'ansible.yml'
      plugin :ansible, Proxy::Ansible::VERSION
      default_settings :ansible_dir => Dir.home,
                       :ansible_environment_file => '/etc/foreman-proxy/ansible.env'
                       # :working_dir => nil

      load_classes ::Proxy::Ansible::ConfigurationLoader
      load_validators :validate_settings => ::Proxy::Ansible::ValidateSettings
      validate :validate!, :validate_settings => nil
    end
  end
end
