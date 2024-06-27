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
    end
  end
end
