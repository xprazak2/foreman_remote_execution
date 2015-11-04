module Actions
  module RemoteExecution
    class ImportAnsibleInventory < AbstractAnsibleJob

      def resource_locks
        :link
      end

      include ::Dynflow::Action::Cancellable

      def plan(proxy)
        input[:job_name] = "Import inventory"
        playbook = <<PLAYBOOK
---
- hosts: all
  tasks:
PLAYBOOK

        ansible_command = plan_action(RunProxyAnsibleCommand, proxy, nil, playbook)
        plan_action(ImportAnsibleEvents, :raw_data => ansible_command.output[:proxy_output][:result])
      end
    end
  end
end
