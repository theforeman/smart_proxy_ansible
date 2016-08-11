require 'smart_proxy_dynflow'

module Proxy
  module Ansible
    class << self
      def initialize
        @dispatcher = Proxy::Ansible::Dispatcher.spawn('proxy-ansible-dispatcher',
                                                       :clock  => SmartProxyDynflowCore::Core.instance.world.clock,
                                                       :logger => SmartProxyDynflowCore::Core.instance.world.logger)
      end

      def dispatcher
        @dispatcher || initialize
      end
    end

    require 'smart_proxy_ansible/events_handler'
    require 'smart_proxy_ansible/command'
    require 'smart_proxy_ansible/connector'
    require 'smart_proxy_ansible/dispatcher'
    require 'smart_proxy_ansible/session'
    require 'smart_proxy_ansible/version'
    require 'smart_proxy_ansible/plugin'
  end
end
