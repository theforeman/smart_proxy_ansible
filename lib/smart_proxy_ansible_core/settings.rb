require 'ostruct'

module Proxy
  module Ansible
    module Core
      class Settings < SmartProxyDynflowCore::Settings

        DEFAULT_SETTINGS = {
          :enabled => true,
          :ansible_working_dir => '/var/tmp'
        }

        def initialize(settings = {})
          super(DEFAULT_SETTINGS.merge(settings))
        end

        def load_settings_from_proxy
          DEFAULT_SETTINGS.keys.each do |key|
            self.class.instance[key] = Proxy::Ansible::Plugin.settings[key]
          end
        end

        def self.create!(input = {})
          settings = self.new input
          self.instance = settings
        end

        def self.instance
          SmartProxyDynflowCore::SETTINGS.plugins['smart_proxy_ansible_core']
        end

        def self.instance=(settings)
          SmartProxyDynflowCore::SETTINGS.plugins['smart_proxy_ansible_core'] = settings
        end
      end
    end
  end
end
Proxy::Ansible::Core::Settings.create!
