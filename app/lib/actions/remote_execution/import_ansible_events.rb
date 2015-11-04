module Actions
  module RemoteExecution
    class ImportAnsibleEvents < Actions::Base
      def run
        imported_hosts, failed_hosts = 0, 0
        facts_by_hostname.each do |hostname, facts|
          begin
            Host::Managed.import_host_and_facts(hostname.dup, facts, hostname.dup)
            imported_hosts += 1
          rescue ActiveRecord::ActiveRecordError => e
            ::Foreman::Logging.exception("Failed to import facts for #{hostname}", e)
            failed_hosts += 1
          end
        end
        output.merge!(:imported_hosts => imported_hosts, :failed_hosts => failed_hosts)
      end

      def raw_data
        input[:raw_data]
      end

      def raw_events
        raw_data.select { |o| o['output_type'] == 'event' }
      end

      def fact_events
        raw_events.select { |o| o['output']['data'].key?('ansible_facts') }
      end

      def facts_by_hostname
        fact_events.inject({}) do |hash, event|
          hostname = event['output']['host']
          facts = event['output']['data'].merge('_type' => 'ansible', '_timestamp' => reformat_timestamp(event['timestamp']))
          hash.update(hostname => facts)
        end
      end

      def reformat_timestamp(raw_timestamp)
        Time.at(raw_timestamp).strftime('%Y-%m-%d %H:%M:%S %f')
      end
    end
  end
end
