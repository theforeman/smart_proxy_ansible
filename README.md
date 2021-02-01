# Smart-proxy Ansible plugin

Proxy plugin to make [foreman_ansible](https://github.com/theforeman/foreman_ansible) actions run in the proxy

## Compatibility

This plugin requires at least Foreman Proxy 2.3.

## Installation (in development)

### Prerequisites

We expect your proxy to also have
[smart_proxy_dynflow](https://github.com/theforeman/smart_proxy_dynflow) 0.1.5
at least, and [foreman-tasks-core](https://github.com/theforeman/foreman-tasks) as
a gem requirement.

### Get the code

**Smart proxy part**

Clone the repository:

```
git clone git@github.com:theforeman/smart_proxy_ansible.git
```

Point the foreman proxy to use this plugin with this line in proxy's `bundler.d/Gemfile.local.rb`
assuming the smart proxy and `smart_proxy_ansible` share the same parent directory.

```
gem 'smart_proxy_ansible', :path => '../smart_proxy_ansible'
```

Enable the plugin in proxy's `config/settings.d/ansible.yml`:

```
---
:enabled: true
```

**Foreman part**

Refer to [foreman_ansible](https://github.com/theforeman/foreman_ansible) instructions.

### Check it's working

After the proxy are up and running, reload the proxy features on Foreman (Infrastructure > Smart Proxies)
and the Ansible feature should appear as a new one.

At this point, you should be able to trigger foreman_ansible actions such as running roles for a host
and they will run in the proxy when it's available. You should be able to see the output of these
jobs under 'Monitor > Tasks' in Foreman.
