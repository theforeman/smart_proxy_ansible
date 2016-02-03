require 'smart_proxy_ansible/api'

map "/ansible" do
  run Proxy::Ansible::Api
end
