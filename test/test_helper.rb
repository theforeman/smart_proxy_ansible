# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/spec'
require 'mocha/minitest'
require 'smart_proxy_for_testing'

require "minitest/reporters"
Minitest::Reporters.use!

module Minitest
  # Modifications to allow a 'test 'nameoftest' do' syntax
  class Test
    class << self
      def test(name, &block)
        test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
        defined = method_defined? test_name
        raise "#{test_name} is already defined in #{self}" if defined

        if block
          define_method(test_name, &block)
        else
          define_method(test_name) do
            flunk "No implementation provided for #{name}"
          end
        end
      end
    end
  end
end
