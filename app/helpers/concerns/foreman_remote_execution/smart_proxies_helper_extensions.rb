module ForemanRemoteExecution
  module SmartProxiesHelperExtensions
    extend ActiveSupport::Concern

    included do
      alias_method_chain :proxy_actions, :ansible_proxy
    end

    def proxy_actions_with_ansible_proxy(proxy, authorizer)
      ansible = proxy.features.detect { |feature| feature.name == 'Ansible' }
      [
        if ansible
          link_to(_("Import Ansible Inventory"), hash_for_import_inventory_ansible_proxy_path(proxy), :method => :post)
          #link_to(_("Import Ansible Inventory"), :controller => 'job_invocations', :action => 'create', :method => :post)
        end
      ] + proxy_actions_without_ansible_proxy(proxy, authorizer)
    end
  end
end
