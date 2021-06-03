# frozen_string_literal: true

require 'foreman_tasks_core/shareable_action'

module Proxy::Ansible
  module Actions
    # Action that can be run both on Foreman or Foreman proxy side
    # to execute the playbook run
    class RunPlaybook < ForemanTasksCore::Runner::Action
      def initiate_runner
        Proxy::Ansible::Runner::Playbook.new(
          input[:inventory],
          input[:playbook],
          input[:options]
        )
      end
    end
  end
end
