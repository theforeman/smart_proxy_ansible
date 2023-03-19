# frozen_string_literal: true

require 'test_helper'
require 'smart_proxy_ansible'
require 'smart_proxy_ansible/runner/ansible_runner'

module Proxy::Ansible
  module Runner
    class AnsibleRunnerTest < Minitest::Test
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
        let(:inventory) do
          { 'all' => { 'hosts' => ['foreman.example.com'] },
            '_meta' => { 'hostvars' => { 'foreman.example.com' => {} } } }
        end
        let(:input) do
          host_secrets = { 'ansible_password' => 'letmein', 'ansible_become_password' => 'iamroot' }
          secrets = { 'per-host' => { 'foreman.example.com' => host_secrets } }
          host_input = { 'input' => { 'action_input' => { 'secrets' => secrets } } }
          { 'foreman.example.com' => host_input }
        end
        let(:runner) { ::Proxy::Ansible::Runner::AnsibleRunner.allocate }

        test 'uses secrets from inventory' do
          test_inventory = inventory.merge('ssh_password' => 'sshpass', 'effective_user_password' => 'mypass')
          rebuilt = runner.send(:rebuild_secrets, test_inventory, input)
          host_vars = rebuilt.dig('_meta', 'hostvars', 'foreman.example.com')
          assert_equal 'sshpass', host_vars['ansible_password']
          assert_equal 'mypass', host_vars['ansible_become_password']
        end

        test 'host secrets are used when not overriden by inventory secrest' do
          rebuilt = runner.send(:rebuild_secrets, inventory, input)
          host_vars = rebuilt.dig('_meta', 'hostvars', 'foreman.example.com')
          assert_equal 'letmein', host_vars['ansible_password']
          assert_equal 'iamroot', host_vars['ansible_become_password']
        end
      end

      describe '#publish_exit_status' do
        let(:ansible_versions) { ['2.12.2', '2.13.3'] }
        let(:suspended_action) { ::Dynflow::Action::Suspended.allocate }
        let(:artifacts_path) { File.join(__dir__, 'fixtures/artifacts') }
        let(:host1) { 'rhel8-new-machine-nofar.example.com' }
        let(:host2) { 'rhel9-nofar-new-machine.example.com' }

        describe 'when running Ansible roles on multiple hosts' do
          # Helper method to create an AnsibleRunner instance for a given test
          def create_runner(test_name, version)
            action_input = JSON.parse(File.read("#{artifacts_path}/#{test_name}/action_input.json"))
            runner = ::Proxy::Ansible::Runner::AnsibleRunner.new(Dynflow::Utils::IndifferentHash.new(action_input), suspended_action: suspended_action)
            runner.instance_variable_set('@root', "#{artifacts_path}/#{test_name}/#{version}")
            runner
          end

          def run_test(test_name, version, exit_statuses)
            runner = create_runner(test_name, version)

            # TODO: replace the second argument with the real status here
            runner.send(:publish_exit_status, 4)

            exit_statuses.each do |host, status|
              assert runner.instance_variable_get('@exit_statuses').key?(host), "Missing exit status for host '#{host}'"
              assert_equal runner.instance_variable_get('@exit_statuses')[host], status,
                           "Incorrect exit status for host '#{host}': expected #{status}, got #{runner.instance_variable_get('@exit_statuses')[host]}"
            end
          end

          it 'sets correct exit status when one host is unreachable' do
            exit_statuses = { host1 => 0, host2 => 1 }
            ansible_versions.each do |version|
              run_test('unreachable_host', version, exit_statuses)
            end
          end

          it 'sets correct exit status when one host has a failed role' do
            exit_statuses = { host1 => 2, host2 => 0 }
            ansible_versions.each do |version|
              run_test('failed_role', version, exit_statuses)
            end
          end

          it 'sets correct exit status when one host has a nonexisting role' do
            exit_statuses = { host1 => 0, host2 => 4 }
            ansible_versions.each do |version|
              run_test('nonexisting_role', version, exit_statuses)
            end
          end
        end
      end
    end
  end
end
