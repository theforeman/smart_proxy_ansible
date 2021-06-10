require 'smart_proxy_dynflow/action/runner'

module Proxy::Ansible
  module TaskLauncher
    class Playbook < Proxy::Dynflow::TaskLauncher::Batch
      class PlaybookRunnerAction < Proxy::Dynflow::Action::Runner
        def initiate_runner
          additional_options = {
            :step_id => run_step_id,
            :uuid => execution_plan_id
          }
          ::Proxy::Ansible::RemoteExecutionCore::AnsibleRunner.new(
            input.merge(additional_options),
            :suspended_action => suspended_action
          )
        end
      end

      def child_launcher(parent)
        ::Proxy::Dynflow::TaskLauncher::Single.new(world, callback, :parent => parent,
                                                                    :action_class_override => PlaybookRunnerAction)
      end
    end
  end
end
