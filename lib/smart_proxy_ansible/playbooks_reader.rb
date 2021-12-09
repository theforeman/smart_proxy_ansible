module Proxy
  module Ansible
    # Implements the logic needed to read the playbooks and associated information
    class PlaybooksReader
      class << self
        def playbooks_names
          ReaderHelper.collections_paths.split(':').flat_map { |path| get_playbooks_names(path) }
        end

        def playbooks(playbooks_to_import)
          ReaderHelper.collections_paths.split(':').reduce([]) do |playbooks, path|
            playbooks.concat(read_collection_playbooks(path, playbooks_to_import))
          end
        end

        def get_playbooks_names(collections_path)
          Dir.glob("#{collections_path}/ansible_collections/*/*/playbooks/*").map do |path|
            ReaderHelper.playbook_or_role_full_name(path)
          end
        end

        def read_collection_playbooks(collections_path, playbooks_to_import = nil)
          Dir.glob("#{collections_path}/ansible_collections/*/*/playbooks/*").map do |path|
            name = ReaderHelper.playbook_or_role_full_name(path)
            {
              name: name,
              playbooks_content: File.readlines(path)
            } if playbooks_to_import.nil? || playbooks_to_import.include?(name)
          end.compact
        rescue Errno::ENOENT, Errno::EACCES => e
          message = "Could not read Ansible playbooks #{collections_path} - #{e.message}"
          raise ReadPlaybooksException, message
        end
      end
    end
  end
end
