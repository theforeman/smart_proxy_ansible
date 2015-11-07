# Smart-proxy Ansible plugin

**Warning - this project hasn't been released yet, and might change significantly. Please don't use in production**

A prove of concept for using Ansible as a provider in Foreman Remote Execution.

## Installation (in development)

### Prerequisities

We expect you have running development version of [Foreman Remote Execution](https://github.com/theforeman/foreman_remote_execution)
and [Smart proxy SSH](https://github.com/theforeman/smart_proxy_remote_execution_ssh).

### Get the code

**Smart proxy part**

Clone the repository:

```
git clone git@github.com:iNecas/smart_proxy_ansible.git
```

Point the foreman proxy to use this plugin with this line in proxy's `bundler.d/Gemfile.local.rb`
(assuming the smart proxy and `smart_proxy_ansible` share the same parent directory.

```
gem 'smart_proxy_ansible', :path => '../smart_proxy_ansible'
```

Enable the plugin in proxy's `config/settings.d/ansible.yml`:

```
---
:enabled: true
```

Install

```
bundle install
```

**Foreman part**

Point Foreman to the Ansible branch of Foreman Remote Execution with this line in Foreman's `bundler.d/Gemfile.local.rb`
including the `foreman_ansible` plugin.

```ruby
gem 'foreman_ansible', :git => 'https://github.com/dLobatog/foreman_ansible.git'
gem 'foreman_remote_execution', :git => 'https://github.com/iNecas/foreman_remote_execution.git', :branch => 'ansible'
```

Prepare your foreman for the new code:

```
bundle install
bundle exec rake db:migrate
bundle exec rake db:seed
```

### Prepare the environment

The plugin works on top of an ansible working directory. This directory needs to be configured to use
the callback plugin from the `smart_proxy_ansible`. One can configure this in `ansible.cfg` to
use the callback directory from this repository:

```
[defaults]
callback_plugins = ../smart_proxy_ansible/ansible/callback_plugins/
```

Or copy the `ansible/callback_plugins/event_per_file_log.py` from this repository to your callbacks directory.
For an example of an Ansible working directory, you can use [foreman_remote_execution_testenv](https://github.com/iNecas/foreman_remote_execution_testenv):

```
git clone git@github.com:iNecas/foreman_remote_execution_testenv.git -b ansible
```

Follow the README instructions to spawn some docker containers with sshd running.

To check the working directory is configured properly, try running a simple playbook
from that directory:

```
ANSIBLE_EVENTS_DIR='events/test' ansible-playbook playbooks/simple.yml
```

The playbook should iterate over the hosts in the inventory (using the `docker.py` inventory file
to load the metadata from docker. In the `events/test` directory. you should see some json files with the data
about the run.

In the proxy's `config/settings.d/ansible.yml` config file, point the plugin to use the right Ansible working dir:

```
:ansible_working_dir: '../foreman_remote_execution_testenv'
```

### Check it's working

After the services are up and running, reload the features on the proxy: the Ansible feature should appear as a new one.

Now, let's try the importing of inventory works, by using 'Import Ansible Inventory' from the proxy actions.
You should start seeing the ansible-playbook output running. At the end, the hosts from the run
should appear in the Foreman's hosts.

The Foreman Remote Execution Ansible branch seeds some jobs templates with the code:

* Run Ansible Module - Ansible Defualt:  run an arbitrary Ansible module against set of hosts (such as `module:"debug" args:"msg=Hello"`

* Package Action - Ansible Default: Ansible's impelmentation of Package Action - SSH Default

* Install Foreman Proxy via Ansible: an example of mapping Foreman hosts to Ansible groups using scoped search.

  For example: `target:"name=myproxy.example.com or name=foreman.example.com" foreman_hosts:"name=foreman.example.com" proxy_hosts:"name=myproxy.example.com"`
  The playbook is defined in the `foreman_remote_execution_testenv` and it's too simplified to be used in production environment.
