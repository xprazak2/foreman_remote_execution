module Actions
  module RemoteExecution
    class RunAnsibleJob < Actions::EntryAction

      def resource_locks
        :link
      end

      include ::Dynflow::Action::Cancellable

      def plan(job_invocation, template_invocation, proxy, connection_options = {})
        input[:job_name] = job_invocation.job_name

        raise _("Could not use any template used in the job invocation") if template_invocation.blank?

        settings =  { :global_proxy   => 'remote_execution_global_proxy',
                      :fallback_proxy => 'remote_execution_fallback_proxy' }

        raise _("Could not use any proxy. Consider configuring %{global_proxy} " +
                    "or %{fallback_proxy} in settings") % settings if proxy.blank?
        template_sections = Hash[template_invocation.template.template.split('# SECTION ').reject(&:empty?).map { |p| p.split("\n", 2) }]
        expected_sections = %w[HOST_VARS ROLES GROUP_VARS PLAYBOOK]
        required_sections = %w[HOST_VARS PLAYBOOK]
        if missing_parts = (required_sections - template_sections.keys) && !missing_parts.empty?
          raise _("Missing template sections: %s") % missing_parts.inspect
        end

        if unexpected_parts = (template_sections.keys - expected_sections) && !unexpected_parts.empty?
          raise _("Unexpected template sections: %s") % unexpected_parts
        end


        host_vars = job_invocation.targeting.hosts.inject({}) do |h, host|
          h.merge(host.hostname => render_section(template_invocation, template_sections, 'HOST_VARS', host))
        end

        group_vars = render_section(template_invocation, template_sections, 'GROUP_VARS')
        roles = render_section(template_invocation, template_sections, 'ROLES')
        inventory = prepare_inventory(host_vars, group_vars, roles)

        playbook = YAML.dump(render_section(template_invocation, template_sections, 'PLAYBOOK'))

        link!(job_invocation)
        link!(template_invocation)

        ansible_command = plan_action(RunProxyAnsibleCommand, proxy, inventory, playbook, { :connection_options => connection_options })
        plan_action(ImportAnsibleEvents, :raw_data => ansible_command.output[:proxy_output][:result])
      end

      def render_section(template_invocation, template_sections, part, host = nil)
        renderer = InputTemplateRenderer.new(template_invocation.template, host, template_invocation, template_sections[part].to_s)
        playbook_data = renderer.render
        raise _("Failed rendering template section %s: %s") % [part, renderer.error_message] unless playbook_data
        YAML.load(playbook_data)
      end

      def prepare_inventory(host_vars, group_vars, roles)
        ret = ""
        host_vars.each do |name, vars|
          ret << "#{name} #{ vars.map { |k, v| %{#{ k }="#{ v }"} }.join(' ') }\n"
        end
        if roles
          roles.each do |name, hosts|
            ret << "[#{name}]\n#{ hosts.join("\n") }\n"
          end
        end
        if group_vars
          group_vars.each do |name, vars|
            ret << "[#{name}:vars]\n#{ vars.map { |(k, v)| %{#{ k }="#{ v }"} }.join("\n") }}\n"
          end
        end
        ret
      end

      def prepare_playbook(playbooks_data)
        if playbooks_data.empty?
          raise _("No playbook rendered")
        else
          return YAML.dump(playbooks_data.first['playbook'])
        end
      end

      def humanized_output
        live_output.map { |line| line['output'].chomp }.join("\n")
      end

      def live_output
        command_action = planned_actions(RunProxyAnsibleCommand).first
        return [] unless command_action
        command_action.live_output.select { |o| o['output_type'] != 'event' }
      end

      def humanized_name
        _('Run %{job_name}') % { :job_name => input[:job_name]}
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
