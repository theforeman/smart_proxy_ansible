require 'smart_proxy_dynflow'

module Proxy
  # Basic requires for this plugin
  module Ansible
    require 'smart_proxy_ansible/version'
    require 'smart_proxy_ansible/configuration_loader'
    require 'smart_proxy_ansible/validate_settings'
    require 'smart_proxy_ansible/plugin'
    require 'smart_proxy_ansible/roles_reader'
    require 'smart_proxy_ansible/playbooks_reader'
    require 'smart_proxy_ansible/reader_helper'
    require 'smart_proxy_ansible/variables_extractor'
    require 'smart_proxy_ansible/vcs_cloner'
    require 'git'
  end
end
