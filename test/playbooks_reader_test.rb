require 'test_helper'
require_relative '../lib/smart_proxy_ansible/playbooks_reader'
require_relative '../lib/smart_proxy_ansible/exception'
require_relative '../lib/smart_proxy_ansible/reader_helper'

class PlaybooksReaderTest < Minitest::Test
  describe 'playbooks method' do
    let(:fixtures) { JSON.parse(File.read(File.join(__dir__, 'fixtures/playbooks_reader_data.json'))) }
    let(:ansible_config) { fixtures['ansible_config'] }

    describe 'playbooks method with error' do
      it 'raises error if the playbooks path is not readable' do
        File.expects(:readlines).with('/etc/ansible/ansible.cfg').returns(ansible_config)
        Proxy::Ansible::PlaybooksReader.expects(:read_collection_playbooks)
                                       .with('/etc/ansible/collections', nil)
                                       .raises(Proxy::Ansible::ReadPlaybooksException.new('Could not read Ansible playbooks'))
        ex = assert_raises(Proxy::Ansible::ReadPlaybooksException) do
          Proxy::Ansible::PlaybooksReader.playbooks(nil)
        end
        assert_match(/Could not read Ansible playbooks/, ex.message)
      end
    end

    describe 'playbooks method no error' do
      let(:listings) { fixtures['listings'] }
      let(:ansible_config) { fixtures['ansible_config'] }
      let(:playbook1) { fixtures['playbook1'] }
      let(:playbook2) { fixtures['playbook2'] }
      let(:playbook3) { fixtures['playbook3'] }

      before do
        Dir.expects(:glob).with('/etc/ansible/collections/ansible_collections/*/*/playbooks/*').returns(listings)
        Dir.expects(:glob).with('/usr/share/ansible/collections/ansible_collections/*/*/playbooks/*').returns([])
        File.expects(:readlines).with('/etc/ansible/ansible.cfg').returns(ansible_config)
        File.expects(:read).with(listings[0]).returns(playbook2)
        File.expects(:read).with(listings[1]).returns(playbook3)
      end

      it 'should return playbooks array of specific playbooks' do
        playbooks_names = %w[xprazak2.forklift_collection.freeipa_server xprazak2.forklift_collection.upgrade]
        res = Proxy::Ansible::PlaybooksReader.playbooks(playbooks_names)
        assert_equal Array, res.class
        assert_equal 2, res.count
      end

      it 'should return playbooks array of all existing playbooks' do
        File.expects(:read).with(listings[2]).returns(playbook1)
        res = Proxy::Ansible::PlaybooksReader.playbooks(nil)
        assert_equal Array, res.class
        assert_equal 3, res.count
      end
    end
  end

  describe 'playbooks_names method' do
    let(:playbooks_names) { %w[xprazak2.forklift_collection.freeipa_server.yml xprazak2.forklift_collection.upgrade.yaml] }
    before do
      Dir.expects(:glob).with('/usr/share/ansible/collections/ansible_collections/*/*/playbooks/*').returns([])
      Dir.expects(:glob).with('/etc/ansible/collections/ansible_collections/*/*/playbooks/*').returns(playbooks_names)
    end

    it 'should return playbooks names as an array' do
      res = Proxy::Ansible::PlaybooksReader.playbooks_names
      assert_equal Array, res.class
      assert_equal 2, res.count
    end

    it 'should return playbooks names with no .yml or .yaml extension' do
      res = Proxy::Ansible::PlaybooksReader.playbooks_names
      assert_equal Array, res.class
      assert_equal 2, res.count
      refute_match res.first, /.ya?ml/
      refute_match res.last, /.ya?ml/
    end
  end
end
