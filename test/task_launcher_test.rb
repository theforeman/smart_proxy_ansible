# frozen_string_literal: true

require 'test_helper'
require 'smart_proxy_ansible'
require 'smart_proxy_ansible/task_launcher/ansible_runner'
require 'json'

module Proxy::Ansible
  module TaskLauncher
    class AnsibleRunnerTest < Minitest::Test
      INPUT = JSON.parse(File.read(File.join(__dir__, 'fixtures/action_input.json')))

      describe Proxy::Ansible::TaskLauncher::AnsibleRunner do
        describe '#transform_input' do
          let(:launcher) { AnsibleRunner.allocate }
          let(:result) { launcher.transform_input(INPUT) }

          it 'keeps task id for matching' do
            _(result['action_input'][:task_id]).must_equal INPUT['action_input']['callback']['task_id']
          end

          it 'keep name for reference' do
            _(result['action_input']['name']).must_equal INPUT['action_input']['name']
          end

          it 'discards everything else' do
            _(result.keys).must_equal ['action_input']
            _(result['action_input'].keys).must_equal ['name', :task_id, :runner_id]
          end
        end
      end
    end
  end
end
