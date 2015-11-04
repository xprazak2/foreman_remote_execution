module Actions
  module RemoteExecution
    class RunProxySshCommand < RunProxyCommand
      def plan(proxy, hostname, script, options = {})
        options = { :effective_user => nil }.merge(options)
        super(proxy, options.merge(:hostname => hostname, :script => script))
      end

      def on_data(data)
        super(data)
        error! _("Script execution failed") if failed_run?
      end


      def failed_run?
        output[:result] == 'initialization_error' ||
            (exit_status && proxy_output[:exit_status] != 0)
      end

      def proxy_action_name
        'Proxy::RemoteExecution::Ssh::CommandAction'
      end
    end
  end
end

