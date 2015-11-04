module Actions
  module RemoteExecution
    class ImportAnsibleEvents < Actions::Base
      def run
        output.merge!(:imported_hosts => 0, :failed_hosts => 0, :imported_reports => 0, :failed_reports => 0)
        facts_by_hostname.each do |hostname, facts|
          import_facts(hostname, facts)
        end
        reports.each do |report|
          import_report(report)
        end
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

      def report_events
        raw_events.reject { |o| o['output']['data'].key?('ansible_facts') }
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

      def import_facts(hostname, facts)
        Host::Managed.import_host_and_facts(hostname.dup, facts, hostname.dup)
        output[:imported_hosts] += 1
      rescue ActiveRecord::ActiveRecordError => e
        ::Foreman::Logging.exception("Failed to import facts for #{hostname}", e)
        output[:failed_hosts] += 1
      end

      def import_report(report)
        Report.import(report)
        output[:imported_reports] += 1
      rescue ::Foreman::Exception => e
        ::Foreman::Logging.exception("Failed to import report #{report}", e)
        output[:failed_reports] += 1
      end

      def reports
        report_events.group_by { |e| e['output']['host'] }.map do |hostname, events|
          status = {'failed' => 0, 'applied' => 0}
          logs = []
          timestamp = nil
          events.each do |event|
            timestamp ||= event['timestamp']
            data = event['output']['data']
            case event['output']['category']
            when "FAILED", "UNREACHABLE", "ASYNC_FAILED"
              status['failed'] += 1
            when "OK", "SKIPPED", "ASYNC_OK"
              status['applied'] += 1
            end
            logs << { 'log' => { 'level' => 'info',
                                 'messages' => { 'message' => data.except('invocation').to_s },
                                 'sources' => { 'source' => data['invocation'].to_s }}}
          end
          { 'host' => hostname,
            'reported_at' => reformat_timestamp(timestamp),
            'metrics' => {},
            'logs' => logs,
            'status' => status }
        end
      end
    end
  end
end
