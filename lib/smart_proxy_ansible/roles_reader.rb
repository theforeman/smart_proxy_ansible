require_relative 'exception'

module Proxy
  module Ansible
    # Implements the logic needed to read the roles and associated information
    class RolesReader
      class << self

        def list_roles
          all_roles = roles_path.split(':').map { |path| read_roles(path) }.flatten
          roles = Set.new(all_roles).to_a
          collection_roles = ReaderHelper.collections_paths.split(':').map { |path| read_collection_roles(path) }.flatten
          roles + collection_roles
        end

        def roles_path_from_settings
          Proxy::Ansible::Plugin.settings[:all_roles_path]
        end

        def roles_path
          ReaderHelper.config_path(ReaderHelper.path_from_config('roles_path'), roles_path_from_settings)
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
            ReaderHelper.playbook_or_role_full_name(path)
          end
        rescue Errno::ENOENT, Errno::EACCES => e
          logger.debug(e.backtrace)
          message = "Could not read Ansible roles #{collections_path} - #{e.message}"
          raise ReadRolesException.new(message), message
        end
      end
    end
  end
end
