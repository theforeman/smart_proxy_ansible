# frozen_string_literal: true

module Proxy
  module Ansible
    # Calls for the smart-proxy API to register the plugin
    class Plugin < Proxy::Plugin

      def self.runtime_dir
        Pathname(ENV['RUNTIME_DIRECTORY'] || '/run').join(plugin_name.to_s)
      end

      def self.state_dir
        Pathname(ENV['STATE_DIRECTORY'] || '/var/lib/foreman-proxy').join(plugin_name.to_s)
      end

      def self.cache_dir
        Pathname(ENV['CACHE_DIRECTORY'] || '/var/cache/foreman-proxy').join(plugin_name.to_s)
      end

      def self.logs_dir
        Pathname(ENV['LOGS_DIRECTORY'] || '/var/logs/foreman-proxy').join(plugin_name.to_s)
      end

      def self.config_dir
        Pathname(ENV['CONFIGURATION_DIRECTORY'] || '/etc/foreman-proxy').join(plugin_name.to_s)
      end

      rackup_path File.expand_path('http_config.ru', __dir__)
      settings_file 'ansible.yml'
      plugin :ansible, Proxy::Ansible::VERSION
      default_settings ansible_dir: Dir.home,
                       ansible_environment_file: '/etc/foreman-proxy/ansible.env',
                       vcs_integration: true,
                       static_roles_paths: %w[/etc/ansible/roles /usr/share/ansible/roles]

      load_programmable_settings do |settings|
        mutable_roles_path = settings[:mutable_roles_path] || state_dir.join('roles')
        system_roles_path = settings[:static_roles_paths].join(':')
        if settings[:vcs_integration]
          unless Pathname.new(mutable_roles_path).exist?
            raise StandardError,
                  "#{mutable_roles_path} does not exist. Create it or disable vcs_integration"
          end
          unless File.writable?(mutable_roles_path)
            raise StandardError,
                  "#{mutable_roles_path} is not writable. Check permissions or disable vcs_integration"
          end

          settings[:all_roles_path] = "#{mutable_roles_path}:#{system_roles_path}"
          settings[:mutable_roles_path] = mutable_roles_path

        else
          settings[:all_roles_path] = system_roles_path
        end
        settings
      end

      load_classes ::Proxy::Ansible::ConfigurationLoader
      load_validators validate_settings: ::Proxy::Ansible::ValidateSettings
      capability :vcs_clone
      validate :validate!, validate_settings: nil
    end
  end
end
