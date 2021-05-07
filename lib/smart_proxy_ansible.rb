require 'smart_proxy_dynflow'

module Proxy
  # Basic requires for this plugin
  module Ansible
    require 'smart_proxy_ansible/version'
    require 'smart_proxy_ansible/plugin'
    require 'smart_proxy_ansible/roles_reader'
    require 'smart_proxy_ansible/variables_extractor'
  end
end
