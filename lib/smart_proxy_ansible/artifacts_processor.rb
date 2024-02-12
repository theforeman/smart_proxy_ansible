require 'json'

module Proxy
  module Ansible
    # Helper for Artifacts Processor
    class ArtifactsProcessor
      ARTIFACTS_DIR = 'artifacts'.freeze

      attr_reader :last_file_num

      def initialize
        @current_file_index = 1
        @last_file_num = 0
      end

      def process_artifacts(root)
        @events_files = []
        @uuid ||= find_uuid(root)
        return unless @uuid

        job_event_dir = File.join(root, ARTIFACTS_DIR, @uuid, 'job_events')

        loop do
          files = Dir["#{job_event_dir}/*.json"].map do |file|
            num = File.basename(file)[/\A\d+/].to_i unless file.include?('partial')
            [file, num]
          end
          files_with_nums = files.select { |(_, num)| num && num >= @current_file_index }.sort_by(&:last)
          break if files_with_nums.empty?

          @events_files.concat(files_with_nums)
          @current_file_index = files_with_nums.last.last + 1
        end
        @current_file_index - 1
      end

      def get_next_event
        file_path = @events_files[@last_file_num][0]
        @last_file_num += 1
        json_event = parse_json_event(file_path)
        ArtifactEvent.new(json_event)
      end

      private

      def find_uuid(root)
        f = Dir["#{root}/#{ARTIFACTS_DIR}/*"].first
        File.basename(f) if f
      end

      def parse_json_event(file_path)
        JSON.parse(File.read(file_path))
      rescue JSON::ParserError => e
        raise ArgumentError, "ERROR: Could not parse value as JSON. Please check the value is a valid JSON #{file_path}."
      end
    end

    class ArtifactEvent
      attr_reader :json_event, :host, :type, :output, :exit_status

      def initialize(json_event)
        @json_event = json_event
        @host = extract_host_name(@json_event)
        @type = @json_event['event']
        @output = @json_event['stdout']
      end

      def set_exit_status
        case @type
        when 'runner_on_ok'
          @exit_status = 0
        when 'runner_on_unreachable'
          @exit_status = 1
        when 'runner_on_failed'
          @exit_status = 2 if @json_event.dig('event_data', 'ignore_errors').nil?
        end
      end

      def parse_failures
        @failures = {
          failures: extract_event_data('failures'),
          unreachable: extract_event_data('dark'),
          rescued: extract_event_data('rescued')
        }
      end

      def has_failures_for_host(host)
        @failures[:failures][host].to_i <= 0 &&
          @failures[:unreachable][host].to_i <= 0 &&
          @failures[:rescued][host].to_i > 0
      end

      private

      def extract_host_name(event)
        hostname = event.dig('event_data', 'host') || event.dig('event_data', 'remote_addr')
        hostname.to_s unless hostname.nil? || hostname.empty?
      end

      def extract_event_data(data_type)
        @json_event.dig('event_data', data_type) || {}
      end
    end
  end
end
