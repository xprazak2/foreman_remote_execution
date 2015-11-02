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
        data['result'].select { |r| r["output_type"] == "event" }.group_by { |r| r["output"]["host"] }.each do |host, events|
          if step = host_step(host)
            world.event(step.execution_plan_id,
                        step.id,
                        ::Actions::ProxyAction::CallbackData.new(events))
          end
        end
        super(data)
      end

      def host_step(host_name)
        @host_steps ||= {}
        return @host_steps[host_name] if @host_steps.key?(host_name)
        sub_task = task.parent_task.sub_tasks.for_resource(Host.find(host_name)).first
        if sub_task
          @host_steps[host_name] = sub_task.execution_plan.entry_action.run_step
        end
        return @host_steps[host_name]
      end
    end
  end
end
