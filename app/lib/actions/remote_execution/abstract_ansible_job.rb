# encoding: UTF-8

module Actions
  module RemoteExecution
    class AbstractAnsibleJob < Actions::EntryAction

      def resource_locks
        :link
      end

      include ::Dynflow::Action::Cancellable

      def humanized_output
        live_output.map { |line| line['output'].chomp }.join("\n")
      end

      def live_output
        command_action = planned_actions(RunProxyAnsibleCommand).first
        return [] unless command_action
        ret = [{ 'output_type' => 'stdout',
                 'output' => "Running Ansible job…",
                 'timestamp' => task.started_at.to_i }]
        ret.concat(command_action.live_output.select { |o| o['output_type'] != 'event' })
        return ret
      end

      def humanized_name
        _('Run %{job_name}') % { :job_name => input[:job_name]}
      end
    end
  end
end
