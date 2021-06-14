require 'minitest/autorun'
require 'minitest/spec'
require 'mocha/minitest'
require 'smart_proxy_for_testing'

# initialize the logger prior testing
# it uses Dir.glob, that we want to stub in some tests
# if those tests run first, it throws unexpected invocation of Dir.glob
::Proxy::LogBuffer::Decorator.instance

module Minitest
  # Modifications to allow a 'test 'nameoftest' do' syntax
  class Test
    class << self
      def test(name, &block)
        test_name = "test_#{name.gsub(/\s+/, '_')}".to_sym
        defined = method_defined? test_name
        raise "#{test_name} is already defined in #{self}" if defined

        if block_given?
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
