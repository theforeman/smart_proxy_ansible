module Proxy::Ansible
  class Plugin < Proxy::Plugin
    http_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))
    https_rackup_path File.expand_path("http_config.ru", File.expand_path("../", __FILE__))

    settings_file "ansible.yml"
    default_settings :ansible_working_dir => '~/.foreman-ansible'
    plugin :ansible, Proxy::Ansible::VERSION
  end
end
