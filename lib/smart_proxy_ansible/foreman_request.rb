require 'proxy/request'

module Proxy
  module Ansible
    class ForemanRequest < ::Proxy::HttpRequest::ForemanRequest
      def post_facts(facts)
        send_request(request_factory.create_post('api/hosts/facts', facts))
      end

      def post_report(report)
        send_request(request_factory.create_post('api/reports', report))
      end
    end
  end
end
