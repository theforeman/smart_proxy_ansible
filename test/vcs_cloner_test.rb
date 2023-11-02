# frozen_string_literal: true

require 'test_helper'
require 'git'

require_relative '../lib/smart_proxy_ansible/vcs_cloner'
require_relative '../lib/smart_proxy_ansible/roles_reader'

# Tests VCSCloner class
class VcsClonerTest < Minitest::Test
  Response = Proxy::Ansible::Response

  describe '#repo_information' do
    payload = {
      'vcs_url' => 'https://github.com/theforeman/smart_proxy_ansible.git'
    }
    demo_info = {
      'head' => {},
      'branches' => {},
      'tags' => {}
    }
    test 'requests repo information' do
      Git.stubs(:ls_remote).returns(demo_info)
      response = Proxy::Ansible::VCSCloner.repo_information payload
      assert_equal Response.new(200, payload.merge(demo_info)), response
    end

    test 'handles a missing parameter correctly' do
      response = Proxy::Ansible::VCSCloner.repo_information({})
      assert_equal Response.new(400, 'Check parameters'), response
    end
  end
  describe '#list_installed_roles' do
    demo_roles = %w[role1 role2 role3]
    test 'correctly lists installed roles' do
      Proxy::Ansible::RolesReader.stubs(:list_roles).returns(demo_roles)
      response = Proxy::Ansible::VCSCloner.list_installed_roles
      assert_equal Response.new(200, demo_roles), response
    end
  end
  describe '#install' do
    demo_repo_info = {
      'vcs_url' => 'https://some.git.url',
      'name' => 'best.role.ever',
      'ref' => 'master'
    }
    test 'installs a role' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(false)
      Proxy::Ansible::VcsClonerHelper.stubs(:install_role).returns(true)
      response = Proxy::Ansible::VCSCloner.install demo_repo_info
      assert_equal Response.new(201, 'Role "best.role.ever" has been created.'), response
    end

    test 'handles a conflict properly' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(true)
      response = Proxy::Ansible::VCSCloner.install demo_repo_info
      assert_equal Response.new(409, 'Role "best.role.ever" already exists.'), response
    end

    test 'handles missing parameter properly' do
      response = Proxy::Ansible::VCSCloner.install({
                                                     'name' => 'best.role.ever',
                                                     'ref' => 'master'
                                                   })
      assert_equal Response.new(400, 'Check parameters'), response
    end
    test 'handles Git error' do
      Proxy::Ansible::VcsClonerHelper.stubs(:install_role).raises(Git::GitExecuteError.new)
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(false)
      response = Proxy::Ansible::VCSCloner.install demo_repo_info
      assert_equal Response.new(400, 'Git Error: Git::GitExecuteError'), response
    end
  end
  describe '#update' do
    demo_repo_info = {
      'vcs_url' => 'https://some.git.url',
      'name' => 'best.role.ever',
      'ref' => 'master'
    }
    test 'updates a role' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(true)
      Proxy::Ansible::VcsClonerHelper.stubs(:update_role).returns(true)
      response = Proxy::Ansible::VCSCloner.update demo_repo_info
      assert_equal Response.new(200, 'Role "best.role.ever" has been updated.'), response
    end
    test 'installs a role' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(false)
      Proxy::Ansible::VcsClonerHelper.stubs(:install_role).returns(true)
      response = Proxy::Ansible::VCSCloner.update demo_repo_info
      assert_equal Response.new(201, 'Role "best.role.ever" has been created.'), response
    end
    test 'handles missing parameter properly' do
      response = Proxy::Ansible::VCSCloner.update({
                                                    'name' => 'best.role.ever',
                                                    'ref' => 'master'
                                                  })
      assert_equal Response.new(400, 'Check parameters'), response
    end
    test 'handles Git error' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(true)
      Proxy::Ansible::VcsClonerHelper.stubs(:update_role).raises(Git::GitExecuteError.new)
      response = Proxy::Ansible::VCSCloner.update demo_repo_info
      assert_equal Response.new(400, 'Git Error: Git::GitExecuteError'), response
    end
  end
  describe '#delete' do
    test 'deletes a role' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(true)
      Proxy::Ansible::VcsClonerHelper.stubs(:delete_role).returns(true)
      response = Proxy::Ansible::VCSCloner.delete({ 'role_name' => 'best.role.ever' })
      assert_equal Response.new(200, 'Role "best.role.ever" has been deleted.'), response
    end

    test 'skips deleting a role' do
      Proxy::Ansible::VcsClonerHelper.stubs(:role_exists).returns(false)
      response = Proxy::Ansible::VCSCloner.delete({ 'role_name' => 'best.role.ever' })
      assert_equal Response.new(200, 'Role "best.role.ever" does not exist. Request ignored.'), response
    end
    test 'handles missing parameter properly' do
      response = Proxy::Ansible::VCSCloner.delete({})
      assert_equal Response.new(400, 'Check parameters'), response
    end
  end
end
