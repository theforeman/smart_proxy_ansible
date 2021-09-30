require 'test_helper'
require_relative '../lib/smart_proxy_ansible/playbooks_reader'
require_relative '../lib/smart_proxy_ansible/exception'
require_relative '../lib/smart_proxy_ansible/reader_helper'

class PlaybooksReaderTest < Minitest::Test

  describe 'playbooks function' do
    before do
      listings = %w[/etc/ansible/collections/ansible_collections/xprazak2/forklift_collection/playbooks/upgrade.yml
       /etc/ansible/collections/ansible_collections/xprazak2/forklift_collection/playbooks/freeipa_server.yml
       /etc/ansible/collections/ansible_collections/xprazak2/forklift_collection/playbooks/foreman_provisioning.yml]
      @playbook1 = ["- hosts: all\n",
                       "  become: true\n",
                       "  vars:\n",
                       "    libvirt_tftp: true\n",
                       "  roles:\n",
                       "    - foreman\n",
                       "    - libvirt\n",
                       "    - foreman_provisioning\n"]

      playbook2 = ["- hosts: all\n",
                          "  become: true\n",
                          "  vars:\n",
                          "    foreman_repositories_version: nightly\n",
                          "    katello_repositories_version: nightly\n",
                          "    foreman_installer_upgrade: True\n",
                          "    foreman_repositories_environment: staging\n",
                          "    katello_repositories_environment: staging\n",
                          "    foreman_installer_scenario: katello\n",
                          "  roles:\n",
                          "    - foreman_server_repositories\n"]

      playbook3 = ["---\n",
                          "- hosts: all\n",
                          "  become: true\n",
                          "  roles:\n",
                          "    - etc_hosts\n",
                          "    - epel_repositories\n",
                          "    - haveged\n",
                          "    - update_os_packages\n",
                          "    - freeipa_server\n"]
      ansible_config = ["# config file for ansible -- https://ansible.com/\n",
                        "# ===============================================\n",
                        "\n",
                        "interpreter_python = /usr/bin/python3\n",
                        "\n",
                        "callback_whitelist = foreman\n",
                        "[callback_foreman]\n",
                        "url = 'http://localhost:3000/'\n",
                        "ssl_cert =\n",
                        "ssl_key =\n",
                        "verify_certs = false"]
      Dir.expects(:glob).with('/etc/ansible/collections/ansible_collections/*/*/playbooks/*').returns(listings)
      Dir.expects(:glob).with('/usr/share/ansible/collections/ansible_collections/*/*/playbooks/*').returns([])
      File.expects(:readlines).with("/etc/ansible/ansible.cfg").returns(ansible_config)
      File.expects(:readlines).with('/etc/ansible/collections/ansible_collections/xprazak2/forklift_collection/playbooks/freeipa_server.yml').returns(playbook3)
      File.expects(:readlines).with('/etc/ansible/collections/ansible_collections/xprazak2/forklift_collection/playbooks/upgrade.yml').returns(playbook2)
    end

    test 'should return playbooks array of specific playbooks' do
      playbooks_names = %w[xprazak2.forklift_collection.freeipa_server.yml xprazak2.forklift_collection.upgrade.yml]
      res = Proxy::Ansible::PlaybooksReader.playbooks(playbooks_names)
      assert_equal Array, res.class
      assert_equal 2, res.count
    end

    test 'should return playbooks array of all existing playbooks' do
      File.expects(:readlines).with('/etc/ansible/collections/ansible_collections/xprazak2/forklift_collection/playbooks/foreman_provisioning.yml').returns(@playbook1)
      res = Proxy::Ansible::PlaybooksReader.playbooks(nil)
      assert_equal Array, res.class
      assert_equal 3, res.count
    end
  end

  test 'should return playbooks names as an array' do
    playbooks_names = %w[ibm.spectrum_virtualize.generic_info.yml ibm.spectrum_virtualize.generic_ansible_sample.yaml xprazak2.forklift_collection.katello_devel.yml xprazak2.forklift_collection.keycloak.yml xprazak2.forklift_collection.rackspace_hostname.yml xprazak2.forklift_collection.etc_hosts_localhost.yml xprazak2.forklift_collection.luna-devel.yml xprazak2.forklift_collection.katello_client.yml xprazak2.forklift_collection.leapp_devel.yml xprazak2.forklift_collection.custom_certificates.yml xprazak2.forklift_collection.libvirt.yml xprazak2.forklift_collection.bats.yml xprazak2.forklift_collection.collect_debug.yml xprazak2.forklift_collection.smoker.yml xprazak2.forklift_collection.foreman_proxy_content_dev.yml xprazak2.forklift_collection.katello.yml xprazak2.forklift_collection.luna_demo_environment.yml xprazak2.forklift_collection.robottelo.yml xprazak2.forklift_collection.foreman_provisioning.yml xprazak2.forklift_collection.rpm_packaging.yml xprazak2.forklift_collection.upgrade.yml xprazak2.forklift_collection.dynflow_devel.yml xprazak2.forklift_collection.foreman_proxy_content.yml xprazak2.forklift_collection.freeipa_server.yml xprazak2.forklift_collection.setup_forklift.yml xprazak2.forklift_collection.luna.yml xprazak2.forklift_collection.fips.yml xprazak2.forklift_collection.squid.yml xprazak2.forklift_collection.foreman.yml xprazak2.forklift_collection.setup_user_devel_environment.yml xprazak2.forklift_collection.foreman_platform.yml xprazak2.forklift_collection.hammer_devel.yml xprazak2.forklift_collection.kubevirt.yml xprazak2.forklift_collection.luna_provisioning.yml xprazak2.forklift_collection.collect_debug_draft.yml xprazak2.forklift_collection.new.yml xprazak2.forklift_collection.new2.yml]
    Dir.expects(:glob).with('/usr/share/ansible/collections/ansible_collections/*/*/playbooks/*').returns([])
    Dir.expects(:glob).with('/etc/ansible/collections/ansible_collections/*/*/playbooks/*').returns(playbooks_names)
    res = Proxy::Ansible::PlaybooksReader.playbooks_names
    assert_equal Array, res.class
    assert_equal 37, res.count
  end

  test 'raises error if the playbooks path is not readable' do
    Proxy::Ansible::PlaybooksReader.expects(:read_collection_playbooks)
                                   .with('/etc/ansible/collections', nil).raises(Proxy::Ansible::ReadPlaybooksException.new('Could not read Ansible roles'))
    ex = assert_raises(Proxy::Ansible::ReadPlaybooksException) do
      Proxy::Ansible::PlaybooksReader.playbooks(nil)
    end
    assert_match(/Could not read Ansible roles/, ex.message)
  end
end
