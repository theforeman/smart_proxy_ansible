# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/smart_proxy_ansible/roles_reader'

# Tests for the Roles Reader service of ansible core,
# this class simply reads roles from its path in ansible.cfg
class RolesReaderTest < Minitest::Test
  CONFIG_PATH = '/etc/ansible/ansible.cfg'
  ROLES_PATH = '/etc/ansible/roles'

  def self.expect_content_config(ansible_cfg_content)
    Proxy::Ansible::RolesReader.expects(:roles_path_from_config)
      .returns(ansible_cfg_content)
  end

  describe '#roles_path' do
    test 'detects commented roles_path' do
      RolesReaderTest.expect_content_config ['#roles_path = thisiscommented!']
      assert_equal(ROLES_PATH,
                   Proxy::Ansible::RolesReader.roles_path)
    end

    test 'returns default path if no roles_path defined' do
      RolesReaderTest.expect_content_config ['norolepath!']
      assert_equal(ROLES_PATH,
                   Proxy::Ansible::RolesReader.roles_path)
    end

    test 'returns roles_path if one is defined' do
      RolesReaderTest.expect_content_config [
        'roles_path = /mycustom/ansibleroles/path'
      ]
      assert_equal('/mycustom/ansibleroles/path',
                   Proxy::Ansible::RolesReader.roles_path)
    end
  end

  describe '#list_roles' do
    test 'reads roles from paths' do
      RolesReaderTest.expect_content_config ["roles_path = #{ROLES_PATH}"]
      Proxy::Ansible::RolesReader.expects(:read_roles).with(ROLES_PATH)
      Proxy::Ansible::RolesReader.list_roles
    end

    test 'reads roles from multiple paths' do
      roles_paths = ['/mycustom/roles/path', '/another/path']
      roles_paths.each do |path|
        Proxy::Ansible::RolesReader.expects(:read_roles).with(path)
      end
      RolesReaderTest.expect_content_config [
        "roles_path = #{roles_paths.join(':')}"
      ]
      Proxy::Ansible::RolesReader.list_roles
    end

    describe 'with unreadable roles path' do
      def setup
        RolesReaderTest.expect_content_config ["roles_path = #{ROLES_PATH}"]
      end

      test 'handles "No such file or dir" with exception' do
        Dir.expects(:glob).with("#{ROLES_PATH}/*").raises(Errno::ENOENT)
        ex = assert_raises(Proxy::Ansible::ReadRolesException) do
          Proxy::Ansible::RolesReader.list_roles
        end
        assert_match(/Could not read Ansible roles/, ex.message)
      end

      test 'raises error if the roles path is not readable' do
        Dir.expects(:glob).with("#{ROLES_PATH}/*").raises(Errno::EACCES)
        ex = assert_raises(Proxy::Ansible::ReadRolesException) do
          Proxy::Ansible::RolesReader.list_roles
        end
        assert_match(/Could not read Ansible roles/, ex.message)
      end
    end

    describe 'with unreadable config' do
      test 'handles "No such file or dir" with exception' do
        File.expects(:readlines).with(CONFIG_PATH).raises(Errno::ENOENT)
        ex = assert_raises(Proxy::Ansible::ReadConfigFileException) do
          Proxy::Ansible::RolesReader.list_roles
        end
        assert_match(/Could not read Ansible config file/, ex.message)
      end

      test 'raises error if the roles path is not readable' do
        File.expects(:readlines).with(CONFIG_PATH).raises(Errno::EACCES)
        ex = assert_raises(Proxy::Ansible::ReadConfigFileException) do
          Proxy::Ansible::RolesReader.list_roles
        end
        assert_match(/Could not read Ansible config file/, ex.message)
      end
    end
  end
end
