# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'smart_proxy_ansible/version'

Gem::Specification.new do |gem|
  gem.name          = 'smart_proxy_ansible'
  gem.version       = Proxy::Ansible::VERSION
  gem.authors       = ['Ivan Nečas', 'Daniel Lobato']
  gem.email         = ['inecas@redhat.com', 'dlobatog@redhat.com']
  gem.homepage      = 'https://github.com/theforeman/smart_proxy_ansible'
  gem.summary       = 'Smart-Proxy Ansible plugin'
  gem.description   = <<-EOS
    Smart-Proxy ansible plugin
  EOS

  gem.files            = Dir['bundler.d/ansible.rb',
                             'settings.d/**/*',
                             'LICENSE', 'README.md',
                             'lib/smart_proxy_ansible.rb',
                             'lib/smart_proxy_ansible/**/*',
                             'bin/json_inventory.sh',
                             'bin/ansible-runner-environment.sh']
  gem.extra_rdoc_files = ['README.md', 'LICENSE']
  gem.test_files       = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths    = ['lib']
  gem.license = 'GPL-3.0-only'
  gem.required_ruby_version = '>= 2.7'

  gem.add_development_dependency 'rake', '~> 13.0'
  gem.add_runtime_dependency('smart_proxy_dynflow', '~> 0.8')
  gem.add_runtime_dependency('smart_proxy_remote_execution_ssh', '~> 0.5')
end
