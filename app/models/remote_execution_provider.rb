class RemoteExecutionProvider
  class << self
    def provider_for(type)
      providers[type.to_s] || providers[:SSH]
    end

    def providers
      @providers ||= { :Ssh => N_(SSHExecutionProvider), :Ansible => N_(AnsibleExecutionProvider)}.with_indifferent_access
    end

    def register(key, klass)
      providers[key.to_sym] = klass
    end

    def provider_names
      providers.keys.map(&:to_s)
    end

    def proxy_command_options(template_invocation, host)
      {}
    end

    def humanized_name
      self.name
    end

    def supports_effective_user?
      false
    end
  end
end
