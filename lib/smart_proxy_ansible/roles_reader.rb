require_relative 'exception'

module Proxy
  module Ansible
    # Implements the logic needed to read the roles and associated information
    class RolesReader
      class << self
        DEFAULT_CONFIG_FILE = '/etc/ansible/ansible.cfg'.freeze
        DEFAULT_ROLES_PATH = '/etc/ansible/roles:/usr/share/ansible/roles'.freeze
        DEFAULT_COLLECTIONS_PATHS = '/etc/ansible/collections:/usr/share/ansible/collections'.freeze

        def list_roles
          roles = roles_path.split(':').map { |path| read_roles(path) }.flatten
          collection_roles = collections_paths.split(':').map { |path| read_collection_roles(path) }.flatten
          roles + collection_roles
        end

        def roles_path
          config_path('roles_path',DEFAULT_ROLES_PATH)
        end

        def collections_paths
          config_path('collections_paths',DEFAULT_COLLECTIONS_PATHS)
        end

        def config_path(config_key,default)
          config_line=path_from_config(config_key)
          # Default to /etc/ansible/roles if none found
          return default if config_line.empty?
          config_line_key = config_line.first.split('=').first.strip
          # In case of commented roles_path key "#roles_path", return default
          return default unless config_line_key == config_key
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
          rescue_and_raise_file_exception ReadRolesException,
                                          roles_path, 'roles' do
            Dir.glob("#{roles_path}/*").map do |path|
              path.split('/').last
            end
          end
        end

        def read_collection_roles(collections_path)
          rescue_and_raise_file_exception ReadRolesException,
                                          collections_path, 'roles' do
            Dir.glob("#{collections_path}/ansible_collections/*/*/roles/*").map do |path|
              parts = path.split('/')
              role = parts.pop
              parts.pop
              collection = parts.pop
              author = parts.pop
              "#{author}.#{collection}.#{role}" 
            end
          end
        end

        def path_from_config(config_key)
          rescue_and_raise_file_exception ReadConfigFileException,
                                          DEFAULT_CONFIG_FILE, 'config file' do
            File.readlines(DEFAULT_CONFIG_FILE).select do |line|
              line =~ /^\s*#{config_key}/
            end
          end
        end

        def rescue_and_raise_file_exception(exception, path, type)
          yield
        rescue Errno::ENOENT, Errno::EACCES => e
          logger.debug(e.backtrace)
          exception_message = "Could not read Ansible #{type} "\
            "#{path} - #{e.message}"
          raise exception.new(exception_message), exception_message
        end
      end
    end
  end
end
