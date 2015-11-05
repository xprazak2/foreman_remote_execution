module Actions
  module RemoteExecution
    class AnsibleHostJob < Actions::EntryAction

      def resource_locks
        :link
      end

      include ::Dynflow::Action::Cancellable

      def plan(job_invocation, host, template_invocation)
        action_subject(host, :job_name => job_invocation.job_name)
        hostname = find_ip_or_hostname(host)

        link!(job_invocation)
        link!(template_invocation)

        plan_self
      end

      def run(event = nil)
        case event
        when nil
          raise "Service restarted unexpectedly" if output[:started]
          output[:started] = true
          suspend
        when ProxyAction::CallbackData
          on_data(event.data)
        else
          raise "Unexpected event #{event.inspect}"
        end
      end

      # @override to put custom logic on event handling
      def on_data(data)
        output[:proxy_output] = data
      end

      def humanized_output
        live_output.map { |line| line['output'].chomp }.join("\n")
      end

      def live_output
        proxy_output = output.try(:[], :proxy_output) || load_live_output
        #require 'pry'; binding.pry if proxy_output.present?
        proxy_output.map do |out|
          output_data = out['output']['data']
          if output_data
            invocation_data = output_data['invocation']
            if invocation_data['module_name'] == 'setup'
              result = 'gathering facts'
            else
              result = JSON.pretty_generate(output_data.except('invocation', 'verbose_always').to_hash)
            end
            out.merge('output' => "#{out['output']['category']}: #{invocation_data['module_name']} #{invocation_data['module_args']}: #{result}")
          else
            out
          end
        end
      end

      def load_live_output
        run_ansible_job = task.parent_task.sub_tasks.where(label: "Actions::RemoteExecution::RunAnsibleJob").first.main_action
        return [] unless run_ansible_job
        proxy_command = run_ansible_job.planned_actions(RunProxyAnsibleCommand).first
        return [] unless proxy_command
        live_output = proxy_command.live_output
        return [] unless live_output
        live_output.select { |o| o["output_type"] == 'event' && o['output']['host'] == input['host']['name'] }
      end

      def humanized_name
        _('Run %{job_name} on %{host}') % { :job_name => input[:job_name], :host => input[:host][:name] }
      end

      def find_ip_or_hostname(host)
        %w(execution primary provision).each do |flag|
          if host.send("#{flag}_interface") && host.send("#{flag}_interface").ip.present?
            return host.execution_interface.ip
          end
        end

        host.interfaces.each do |interface|
          return interface.ip unless interface.ip.blank?
        end

        return host.fqdn
      end
    end
  end
end
