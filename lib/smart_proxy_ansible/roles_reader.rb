require_relative 'exception'

module Proxy
  module Ansible
    # Implements the logic needed to read the roles and associated information
    class RolesReader
      class << self
        DEFAULT_CONFIG_FILE = '/etc/foreman_proxy/ansible.cfg'.freeze
        DEFAULT_ROLES_PATH = '/etc/ansible/roles:/usr/share/ansible/roles'.freeze
        DEFAULT_COLLECTIONS_PATHS = '/etc/ansible/collections:/usr/share/ansible/collections'.freeze

        def list_roles
          roles = roles_path.split(':').map { |path| read_roles(path) }.flatten
          collection_roles = collections_paths.split(':').map { |path| read_collection_roles(path) }.flatten
          roles + collection_roles
        end

        def roles_path
          config_path(path_from_config('roles_path'), DEFAULT_ROLES_PATH)
        end

        def collections_paths
          config_path(path_from_config('collections_paths'), DEFAULT_COLLECTIONS_PATHS)
        end

        def config_path(config_line, default)
          # Default to /etc/ansible/roles if config_line is empty
          return default if config_line.empty?

          config_line_key = config_line.first.split('=').first.strip
          # In case of commented roles_path key "#roles_path" or #collections_paths, return default
          return default if ['#roles_path', '#collections_paths'].include?(config_line_key)

          config_line.first.split('=').last.strip
        end

        def logger
          # Return a different logger depending on where ForemanAnsibleCore is
          # running from
          if defined?(::Foreman::Logging)
            ::Foreman::Logging.logger('foreman_ansible')
          else
            ::Proxy::LogBuffer::Decorator.instance
          end
        end

        private

        def read_roles(roles_path)
          glob_path("#{roles_path}/*").map do |path|
            path.split('/').last
          end
        rescue Errno::ENOENT, Errno::EACCES => e
          logger.debug(e.backtrace)
          message = "Could not read Ansible roles #{roles_path} - #{e.message}"
          raise ReadRolesException.new(message), message
        end

        def glob_path(path)
          Dir.glob path

        end

        def read_collection_roles(collections_path)
          Dir.glob("#{collections_path}/ansible_collections/*/*/roles/*").map do |path|
            parts = path.split('/')
            role = parts.pop
            parts.pop
            collection = parts.pop
            author = parts.pop
            "#{author}.#{collection}.#{role}"
          end
        rescue Errno::ENOENT, Errno::EACCES => e
          logger.debug(e.backtrace)
          message = "Could not read Ansible roles #{collections_path} - #{e.message}"
          raise ReadRolesException.new(message), message
        end

        def path_from_config(config_key)
          File.readlines(DEFAULT_CONFIG_FILE).select do |line|
            line =~ /^\s*#{config_key}/
          end
        rescue Errno::ENOENT, Errno::EACCES => e
          logger.debug(e.backtrace)
          message = "Could not read Ansible config file #{DEFAULT_CONFIG_FILE} - #{e.message}"
          raise ReadConfigFileException.new(message), message
        end
      end
    end
  end
end
