module Actions
  module RemoteExecution
    class RunProxyAnsibleCommand < RunProxyCommand
      def plan(proxy, inventory, playbook, options = {})
        options = { :effective_user => nil }.merge(options)
        super(proxy, options.merge(:inventory => inventory, :playbook => playbook))
      end

      def proxy_action_name
        'Proxy::Ansible::Command::Playbook::Action'
      end

      def on_data(data)
        if task.parent_task.respond_to?(:sub_tasks)
          host_events = data['result'].select { |r| r["output_type"] == "event" }.group_by { |r| r["output"]["host"] }
          host_steps = self.host_steps
          host_events.each do |hostname, events|
            if step = host_steps[hostname]
              world.event(step.execution_plan_id,
                          step.id,
                          ::Actions::ProxyAction::CallbackData.new(events))
            end
          end

          missed_hosts = host_steps.keys - host_events.keys
          missed_hosts.each do |host|
            step = host_steps[host]
            world.event(step.execution_plan_id,
                        step.id,
                        ::Actions::ProxyAction::CallbackData.new([{"output_type" => "debug", "output" => "No events", "timestamp" => Time.now.to_f}]))
          end
        end
        super(data)
      end

      def host_steps
        host_tasks = task.parent_task.sub_tasks.for_action_types(Actions::RemoteExecution::AnsibleHostJob.name)
        host_tasks.each_with_object({}) do |task, hash|
          host = task.locks.where(:resource_type => Host::Managed.name).first.try(:resource)
          if host
            hash[host.hostname] = task.execution_plan.entry_action.run_step
          end
        end
      end
    end
  end
end
