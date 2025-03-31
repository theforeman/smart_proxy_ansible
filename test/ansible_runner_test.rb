# frozen_string_literal: true

require 'test_helper'
require 'smart_proxy_ansible'
require 'smart_proxy_ansible/runner/ansible_runner'
require 'json'
require 'smart_proxy_remote_execution_ssh'
require 'smart_proxy_remote_execution_ssh/utils'

module Proxy::Ansible
  module Runner
    class AnsibleRunnerTest < Minitest::Test
      def setup
        # Setup remote execution plugin settings
        Proxy::RemoteExecution::Ssh::Plugin.load_test_settings({})
      end

      describe Proxy::Ansible::Runner::AnsibleRunner do
        it 'parses files without event data' do
          content = <<~JSON
            {"uuid": "a29d8592-f805-4d0e-b73d-7a53cc35a92e", "stdout": " [WARNING]: Consider using the yum module rather than running 'yum'.  If you", "counter": 8, "end_line": 8, "runner_ident": "e2d9ae11-026a-4f9f-9679-401e4b852ab0", "start_line": 7, "event": "verbose"}
          JSON

          File.expects(:read).with('fake.json').returns(content)
          runner = AnsibleRunner.allocate
          runner.expects(:handle_broadcast_data)
          assert runner.send(:handle_event_file, 'fake.json')
        end
      end

      describe '#rebuild_secrets' do
        let(:inventory) { { 'all' => { 'hosts' => { 'foreman.example.com' => {} } } } }
        let(:host_secrets) { { 'ansible_password' => 'letmein', 'ansible_become_password' => 'iamroot' } }
        let(:rex_secrets) { { 'ssh_password' => 'sshpass', 'effective_user_password' => 'mypass' } }

        let(:default_secrets) do
          secrets = { 'per-host' => { 'foreman.example.com' => host_secrets } }
          { 'foreman.example.com' => { 'input' => { 'action_input' => { 'secrets' => secrets } } } }
        end

        let(:rex_input_secrets) do
          secrets = { 'per-host' => { 'foreman.example.com' => host_secrets } }
          { 'foreman.example.com' => { 'input' => { 'action_input' => { 'secrets' => secrets.merge(rex_secrets) } } } }
        end

        let(:runner) { ::Proxy::Ansible::Runner::AnsibleRunner.allocate }

        # Since we don't keep secrets in the host inventory,
        # we can either retrieve them from the host settings or from the REX job input
        test 'uses default secrets' do
          rebuilt = runner.send(:rebuild_secrets, inventory, default_secrets)
          host_vars = rebuilt.dig('all', 'hosts', 'foreman.example.com')
          assert_equal 'letmein', host_vars['ansible_password']
          assert_equal 'iamroot', host_vars['ansible_become_password']
        end

        test 'uses secrets from REX job input' do
          rebuilt = runner.send(:rebuild_secrets, inventory, rex_input_secrets)
          host_vars = rebuilt.dig('all', 'hosts', 'foreman.example.com')
          assert_equal 'sshpass', host_vars['ansible_password']
          assert_equal 'mypass', host_vars['ansible_become_password']
        end
      end

      describe '#rebuild_inventory' do
        let(:runner) { ::Proxy::Ansible::Runner::AnsibleRunner.allocate }
        let(:ssh_key_path) { '/tmp/dummy_id_rsa' }

        before do
          ssh_settings = { ssh_identity_key_file: ssh_key_path }
          Proxy::RemoteExecution::Ssh::Plugin.stubs(:settings).returns(ssh_settings)
        end

        test 'merges hostvars from multiple inventories' do
          input = {
            'host1' => { 'input' => { 'action_input' => {
              'name' => 'host1',
              'ansible_inventory' => {
                '_meta' => { 'hostvars' => { 'host1' => { 'foo' => 'bar' } } },
                'all' => { 'vars' => { 'group_var' => 1 } }
              } } } },
            'host2' => { 'input' => { 'action_input' => {
              'name' => 'host2',
              'ansible_inventory' => {
                '_meta' => { 'hostvars' => { 'host2' => { 'baz' => 'qux' } } },
                'all' => { 'vars' => { 'group_var' => 2 } }
              } } } }
          }
          inventory = runner.send(:rebuild_inventory, input)
          assert inventory['all']['hosts'].key?('host1')
          assert inventory['all']['hosts'].key?('host2')
          assert_equal 'bar', inventory['all']['hosts']['host1']['foo']
          assert_equal 'qux', inventory['all']['hosts']['host2']['baz']
        end

        test 'sets first_execution flag per host' do
          input = {
            'host1' => { 'input' => { 'action_input' => {
              'name' => 'host1',
              'ansible_inventory' => {
                '_meta' => { 'hostvars' => { 'host1' => { 'foreman' => {} } } },
                'all' => { 'vars' => {} }
              },
              'first_execution' => true
            } } },
            'host2' => { 'input' => { 'action_input' => {
              'name' => 'host2',
              'ansible_inventory' => {
                '_meta' => { 'hostvars' => { 'host2' => { 'foreman' => {} } } },
                'all' => { 'vars' => {} }
              },
              'first_execution' => false
            } } }
          }
          inventory = runner.send(:rebuild_inventory, input)
          assert_equal true, inventory['all']['hosts']['host1']['foreman']['first_execution']
          assert_equal false, inventory['all']['hosts']['host2']['foreman']['first_execution']
        end

        test 'handles missing group vars gracefully' do
          input = {
            'host1' => { 'input' => { 'action_input' => {
              'name' => 'host1',
              'ansible_inventory' => {
                '_meta' => { 'hostvars' => { 'host1' => {} } },
                'all' => {} # no vars
              },
              'first_execution' => true
            } } }
          }
          inventory = runner.send(:rebuild_inventory, input)
          assert_equal({}, inventory['all']['vars'])
        end

        test 'ensures ssh key is set for each host' do
          input = {
            'host1' => { 'input' => { 'action_input' => {
              'name' => 'host1',
              'ansible_inventory' => {
                '_meta' => { 'hostvars' => { 'host1' => {} } },
                'all' => { 'vars' => {} }
              },
              'first_execution' => true
            } } }
          }
          inventory = runner.send(:rebuild_inventory, input)
          assert_equal ssh_key_path, inventory['all']['hosts']['host1'][:ansible_ssh_private_key_file]
        end

        test 'handles empty input gracefully' do
          input = {}
          assert_raises(NoMethodError) do
            runner.send(:rebuild_inventory, input)
          end
        end

        test 'rebuild_inventory works with real input.json fixture' do
          input = JSON.parse(File.read(File.join(__dir__, 'fixtures/input.json')))
          inventory = runner.send(:rebuild_inventory, input)

          # Basic structure checks
          assert inventory.key?('all'), 'Inventory should have an all group'
          assert inventory['all'].key?('hosts'), 'All group should have hosts'
          assert_kind_of Hash, inventory['all']['hosts']

          # Check that at least one host from input is present
          input.keys.each do |host|
            assert inventory['all']['hosts'].key?(host), "Host #{host} should be present in rebuilt inventory"
          end

          # Check that first_execution flag is set correctly
          input.each do |host, data|
            expected_flag = data['input']['action_input']['first_execution']
            actual_flag = inventory['all']['hosts'][host]['foreman']['first_execution']
            assert_equal expected_flag, actual_flag, "first_execution flag for #{host} should match input"
          end
        end
      end

      describe '#prune_known_hosts_on_first_execution' do
        let(:runner) { ::Proxy::Ansible::Runner::AnsibleRunner.allocate }
        let(:logger_stub) { stub(:debug => nil, :warn => nil, :error => nil, :level => 1) }

        before do
          runner.stubs(:logger).returns(logger_stub)
          Proxy::RemoteExecution::Utils.stubs(:prune_known_hosts!)
        end

        test 'skips when inventory has no hosts' do
          runner.instance_variable_set(:@inventory, { 'all' => {} })
          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).never
          runner.send(:prune_known_hosts_on_first_execution)
        end

        test 'skips hosts without first_execution flag' do
          inventory = {
            'all' => {
              'hosts' => {
                'host1.example.com' => {
                  'foreman' => { 'first_execution' => false },
                  'ansible_host' => '192.168.1.1',
                  'ansible_port' => 22
                }
              }
            }
          }
          runner.instance_variable_set(:@inventory, inventory)
          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).never
          runner.send(:prune_known_hosts_on_first_execution)
        end

        test 'skips hosts without foreman interfaces' do
          inventory = {
            'all' => {
              'hosts' => {
                'host1.example.com' => {
                  'foreman' => { 'first_execution' => true },
                  'ansible_host' => '192.168.1.1',
                  'ansible_port' => 22
                }
              }
            }
          }
          runner.instance_variable_set(:@inventory, inventory)
          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).never
          runner.send(:prune_known_hosts_on_first_execution)
        end

        test 'processes all identifiers and ports for host with first execution' do
          inventory = {
            'all' => {
              'hosts' => {
                'host1.example.com' => {
                  'foreman' => {
                    'first_execution' => true,
                    'foreman_interfaces' => [{ 'ip' => '192.168.1.1',
                                               'ip6' => '2001:db8::1',
                                               'name' => 'host1.example.com' }]
                  },
                  'ansible_host' => '192.168.1.2',
                  'ansible_port' => 22,
                  'ansible_ssh_port' => 2222
                }
              }
            }
          }
          runner.instance_variable_set(:@inventory, inventory)

          expected_identifiers = ['192.168.1.1', '2001:db8::1', '192.168.1.2', 'host1.example.com']
          expected_ports = [22, 2222]

          expected_identifiers.product(expected_ports).each do |host, port|
            Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).with(host, port, logger_stub)
          end

          runner.send(:prune_known_hosts_on_first_execution)
        end

        test 'handles hosts with minimal interface information' do
          inventory = {
            'all' => {
              'hosts' => {
                'host1.example.com' => {
                  'foreman' => {
                    'first_execution' => true,
                    'foreman_interfaces' => [{ 'ip' => '192.168.1.1' }]
                  },
                  'ansible_port' => 22
                }
              }
            }
          }
          runner.instance_variable_set(:@inventory, inventory)

          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).with('192.168.1.1', 22, logger_stub)
          runner.send(:prune_known_hosts_on_first_execution)
        end

        test 'processes multiple hosts correctly' do
          inventory = {
            'all' => {
              'hosts' => {
                'host1.example.com' => {
                  'foreman' => {
                    'first_execution' => true,
                    'foreman_interfaces' => [{ 'ip' => '192.168.1.1' }]
                  },
                  'ansible_port' => 22
                },
                'host2.example.com' => {
                  'foreman' => {
                    'first_execution' => false,
                    'foreman_interfaces' => [{ 'ip' => '192.168.1.2' }]
                  },
                  'ansible_port' => 22
                },
                'host3.example.com' => {
                  'foreman' => {
                    'first_execution' => true,
                    'foreman_interfaces' => [{ 'ip' => '192.168.1.3' }]
                  },
                  'ansible_port' => 22
                }
              }
            }
          }
          runner.instance_variable_set(:@inventory, inventory)

          # Should only process host1 and host3
          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).with('192.168.1.1', 22, logger_stub)
          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).with('192.168.1.3', 22, logger_stub)
          Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).with('192.168.1.2', anything, anything).never

          runner.send(:prune_known_hosts_on_first_execution)
        end

        test 'prune_known_hosts_on_first_execution works with real inventory.json fixture' do
          inventory = JSON.parse(File.read(File.join(__dir__, 'fixtures/inventory.json')))
          runner.instance_variable_set(:@inventory, inventory)

          # Find all hosts with first_execution true
          hosts = inventory['all']['hosts'].select do |_, vars|
            vars.dig('foreman', 'first_execution')
          end

          hosts.each do |_, vars|
            interface = vars.dig('foreman', 'foreman_interfaces', 0)
            next unless interface
            identifiers = [interface['ip'], interface['ip6'], vars['ansible_host'], interface['name']].compact.uniq
            ports = [vars['ansible_ssh_port'], vars['ansible_port']].compact.uniq
            identifiers.product(ports).each do |host, port|
              Proxy::RemoteExecution::Utils.expects(:prune_known_hosts!).with(host, port, logger_stub)
            end
          end
          runner.send(:prune_known_hosts_on_first_execution)
        end
      end
    end
  end
end
