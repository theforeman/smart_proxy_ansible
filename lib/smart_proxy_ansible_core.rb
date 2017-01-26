require 'smart_proxy_dynflow_core'

module Proxy
  module Ansible
    class << self
      def initialize
        core_instance = SmartProxyDynflowCore::Core.instance
        @dispatcher = Proxy::Ansible::Core::Dispatcher.spawn('proxy-ansible-dispatcher',
                                                             :clock  => core_instance.world.clock,
                                                             :logger => core_instance.world.logger)
      end

      def dispatcher
        @dispatcher || initialize
      end
    end

    require 'smart_proxy_ansible_core/events_handler'
    require 'smart_proxy_ansible_core/command'
    require 'smart_proxy_ansible_core/connector'
    require 'smart_proxy_ansible_core/dispatcher'
    require 'smart_proxy_ansible_core/session'
    require 'smart_proxy_ansible_core/settings'
    require 'smart_proxy_ansible_core/version'
  end
end
