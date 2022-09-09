# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/smart_proxy_ansible/variables_extractor'
require_relative '../lib/smart_proxy_ansible/exception'

class VariablesExtractorTest < Minitest::Test
  describe '::extract_variables' do
    test 'extracts variables' do
      res = Proxy::Ansible::VariablesExtractor.extract_variables("#{Dir.getwd}/test/fixtures/roles/with_defaults")

      assert_equal Hash, res.class
      assert_equal 13, res.count
      assert_equal "postgres", res["postgresql_user"]
    end

    test 'raises when fails to parse' do
      assert_raises Proxy::Ansible::ReadVariablesException do
        Proxy::Ansible::VariablesExtractor.extract_variables("#{Dir.getwd}/test/fixtures/roles/with_corrupted_defaults")
      end
    end
  end
end
