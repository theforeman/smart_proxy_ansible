require_relative 'exception'

module Proxy
  module Ansible
    # Implements the logic needed to read the roles and associated information
    class RolesReader
      class << self
        def list_roles
          roles_path.split(':').map { |path| read_roles(path) }.flatten
        end

        def roles_path
          roles_line = roles_path_from_config
          exception = ReadConfigFileException.new("Could not find 'roles_path' in #{config_file_path}")
          raise exception if roles_line.empty?
          split_roles_line = roles_line.first.split('=')
          raise exception unless split_roles_line.first.strip == 'roles_path'
          split_roles_line.last.strip
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

        def config_file_path
          File.join ::Proxy::Ansible::Plugin.settings.ansible_working_dir, '.ansible.cfg'
        end

        def read_roles(roles_path)
          rescue_and_raise_file_exception ReadRolesException,
                                          roles_path, 'roles' do
            Dir.glob("#{roles_path}/*").map do |path|
              path.split('/').last
            end
          end
        end

        def roles_path_from_config
          rescue_and_raise_file_exception ReadConfigFileException,
                                          config_file_path, 'config file' do
            File.readlines(config_file_path).select do |line|
              line =~ /^\s*roles_path/
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
