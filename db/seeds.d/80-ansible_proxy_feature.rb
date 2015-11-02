f = Feature.find_or_create_by_name('Ansible')
raise "Unable to create proxy feature: #{format_errors f}" if f.nil? || f.errors.any?
