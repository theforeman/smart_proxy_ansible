# frozen_string_literal: true

require 'test_helper'
require 'foreman_tasks_core'
require 'smart_proxy_ansible'

# Playbook Runner - this class uses foreman_tasks_core
# to run playbooks
class PlaybookRunnerTest < Minitest::Test
  describe 'PlaybookRunner' do
    before do
      Proxy::Ansible::Plugin.stubs(:settings).returns(OpenStruct.new(:ansible_dir => Dir.home))
    end

    describe 'roles dir' do
      test 'reads default when none provided' do
        Proxy::Ansible::Runner::Playbook.any_instance.stubs(:unknown_hosts).
          returns([])
        File.expects(:exist?).with(Dir.home).returns(true)
        Proxy::Ansible::Runner::Playbook.any_instance.expects(:rebuild_secrets).returns(nil)
        runner = Proxy::Ansible::Runner::Playbook.new(nil, nil, :suspended_action => nil)
        assert '/etc/ansible', runner.instance_variable_get('@ansible_dir')
      end
    end

    describe 'working_dir' do
      before do
        Proxy::Ansible::Runner::Playbook.any_instance.stubs(:unknown_hosts).
          returns([])
      end

      test 'creates temp one if not provided' do
        Dir.expects(:mktmpdir)
        File.expects(:exist?).with(Dir.home).returns(true)
        Proxy::Ansible::Runner::Playbook.any_instance.expects(:rebuild_secrets).returns(nil)
        Proxy::Ansible::Runner::Playbook.new(nil, nil, :suspended_action => nil)
      end

      test 'reads it when provided' do
        settings = { :working_dir => '/foo', :ansible_dir => '/etc/foo' }
        Proxy::Ansible::Plugin.expects(:settings).returns(settings)
        File.expects(:exist?).with(settings[:ansible_dir]).returns(true)
        Dir.expects(:mktmpdir).never
        Proxy::Ansible::Runner::Playbook.any_instance.expects(:rebuild_secrets).returns(nil)
        runner = Proxy::Ansible::Runner::Playbook.new(nil, nil, :suspended_action => nil)
        assert '/foo', runner.instance_variable_get('@working_dir')
      end
    end

    describe 'TOFU policy' do # Trust On First Use
      before do
        @inventory = { 'all' => { 'hosts' => ['foreman.example.com'] } }
        @output = StringIO.new
        logger = Logger.new(@output)
        Proxy::Ansible::Runner::Playbook.any_instance.stubs(:logger).
          returns(logger)
      end

      test 'ignores known hosts' do
        Net::SSH::KnownHosts.expects(:search_for).
          with('foreman.example.com').returns(['somekey'])
        Proxy::Ansible::Runner::Playbook.any_instance.
          expects(:add_to_known_hosts).never
        Proxy::Ansible::Runner::Playbook.any_instance.expects(:rebuild_secrets).returns(@inventory)
        Proxy::Ansible::Runner::Playbook.new(@inventory, nil, :suspended_action => nil)
      end

      test 'adds unknown hosts to known_hosts' do
        Net::SSH::KnownHosts.expects(:search_for).
          with('foreman.example.com').returns([])
        Proxy::Ansible::Runner::Playbook.any_instance.
          expects(:add_to_known_hosts).with('foreman.example.com')
        Proxy::Ansible::Runner::Playbook.any_instance.expects(:rebuild_secrets).returns(@inventory)
        Proxy::Ansible::Runner::Playbook.new(@inventory, nil, :suspended_action => nil)
      end

      test 'logs error when it cannot add to known_hosts' do
        Net::SSH::KnownHosts.expects(:search_for).
          with('foreman.example.com').returns([])
        Net::SSH::Transport::Session.expects(:new).with('foreman.example.com').
          raises(::Net::SSH::HostKeyError)
        Proxy::Ansible::Runner::Playbook.any_instance.expects(:rebuild_secrets).returns(@inventory)
        Proxy::Ansible::Runner::Playbook.new(@inventory, nil, :suspended_action => nil)
        assert_match(
          /ERROR.*Failed to save host key for foreman.example.com: Net::SSH::HostKeyError/,
          @output.string
        )
      end
    end

    describe 'rebuild secrets' do
      let(:inventory) do
        { 'all' => { 'hosts' => ['foreman.example.com'] },
          '_meta' => { 'hostvars' => { 'foreman.example.com' => {} } } }
      end
      let(:secrets) do
        host_secrets = { 'ansible_password' => 'letmein', 'ansible_become_password' => 'iamroot' }
        { 'per-host' => { 'foreman.example.com' => host_secrets } }
      end
      let(:runner) { Proxy::Ansible::Runner::Playbook.allocate }

      test 'uses secrets from inventory' do
        test_inventory = inventory.merge('ssh_password' => 'sshpass', 'effective_user_password' => 'mypass')
        rebuilt = runner.send(:rebuild_secrets, test_inventory, secrets)
        host_vars = rebuilt.dig('_meta', 'hostvars', 'foreman.example.com')
        assert_equal 'sshpass', host_vars['ansible_password']
        assert_equal 'mypass', host_vars['ansible_become_password']
      end

      test 'host secrets are used when not overriden by inventory secrest' do
        rebuilt = runner.send(:rebuild_secrets, inventory, secrets)
        host_vars = rebuilt.dig('_meta', 'hostvars', 'foreman.example.com')
        assert_equal 'letmein', host_vars['ansible_password']
        assert_equal 'iamroot', host_vars['ansible_become_password']
      end
    end
  end
end
