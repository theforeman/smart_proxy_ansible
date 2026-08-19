# frozen_string_literal: true

require 'test_helper'
require 'smart_proxy_ansible/artifacts_reader'
require 'fileutils'
require 'tmpdir'

module Proxy::Ansible
  class ArtifactsReaderTest < Minitest::Test
    def setup
      @root = Dir.mktmpdir('smart-proxy-ansible-artifacts')
      @event_directory = File.join(@root, 'artifacts', 'runner-uuid', 'job_events')
      FileUtils.mkdir_p(@event_directory)
      @reader = ArtifactsReader.new(@root)
    end

    def teardown
      FileUtils.remove_entry(@root)
    end

    test 'reads complete event files in counter order' do
      write_event('3-event.json', 'third')
      write_event('1-event.json', 'first')
      write_event('2-partial.json', 'partial')
      write_event('2-event.json', 'second')

      artifacts = @reader.new_artifacts

      assert_equal ['first', 'second', 'third'], artifacts.map(&:content)
      assert_equal ['1-event.json', '2-event.json', '3-event.json'],
        artifacts.map { |artifact| File.basename(artifact.path) }
    end

    test 'only returns events added since the previous read' do
      write_event('1-event.json', 'first')
      assert_equal ['first'], @reader.new_artifacts.map(&:content)

      write_event('2-event.json', 'second')

      assert_equal ['second'], @reader.new_artifacts.map(&:content)
      assert_empty @reader.new_artifacts
    end

    test 'finds an artifact directory created after the first read' do
      FileUtils.remove_entry(File.join(@root, 'artifacts'))
      assert_empty @reader.new_artifacts

      FileUtils.mkdir_p(@event_directory)
      write_event('1-event.json', 'first')

      assert_equal ['first'], @reader.new_artifacts.map(&:content)
    end

    private

    def write_event(filename, content)
      File.write(File.join(@event_directory, filename), content)
    end
  end
end
