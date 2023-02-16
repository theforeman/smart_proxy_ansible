module Proxy
  module Ansible
    # Helper for Playbooks Reader
    class ReaderHelper
      class << self
        DEFAULT_COLLECTIONS_PATHS = '/etc/ansible/collections:/usr/share/ansible/collections'.freeze
        DEFAULT_CONFIG_FILE = '/etc/ansible/ansible.cfg'.freeze

        def collections_paths
          config_path(path_from_config('collections_paths'), DEFAULT_COLLECTIONS_PATHS)
        end

        def config_path(config_line, default)
          return default if config_line.empty?

          config_line_key = config_line.first.split('=').first.strip
          # In case of commented roles_path key "#roles_path" or #collections_paths, return default
          return default if ['#roles_path', '#collections_paths'].include?(config_line_key)

          config_line.first.split('=').last.strip
        end

        def path_from_config(config_key)
          File.readlines(DEFAULT_CONFIG_FILE).select do |line|
            line =~ /^\s*#{config_key}/
          end
        rescue Errno::ENOENT, Errno::EACCES => e
          message = "Could not read Ansible config file #{DEFAULT_CONFIG_FILE}, using defaults - #{e.message}"
          RolesReader.logger.info(message)
          []
        end

        def playbook_or_role_full_name(path)
          parts = path.split('/')
          playbook = parts.pop.sub(/\.ya?ml/, '')
          parts.pop
          collection = parts.pop
          author = parts.pop
          "#{author}.#{collection}.#{playbook}"
        end
      end
    end
  end
end
