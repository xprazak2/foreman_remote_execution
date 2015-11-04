class AnsibleProxiesController < ApplicationController
  def import_inventory
    @proxy = find_proxy
    task = ForemanTasks.async_task(::Actions::RemoteExecution::ImportAnsibleInventory, @proxy)
    redirect_to hash_for_template_invocation_path(:id => task)
  end

  private

  def find_proxy(permission = :view_smart_proxies)
    SmartProxy.authorized(permission).find(params[:id])
  end
end
