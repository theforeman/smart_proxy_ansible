# frozen_string_literal: true

require 'smart_proxy_dynflow/action/runner'

module Proxy::Ansible
  module Actions
    # Action that can be run both on Foreman or Foreman proxy side
    # to execute the playbook run
    class RunPlaybook < Proxy::Dynflow::Action::Runner
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
