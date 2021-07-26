module Proxy
  module Ansible
    # API endpoints. Most of the code should be calling other classes,
    # please keep the actual implementation of the endpoints outside
    # of this class.
    class Api < Sinatra::Base
      include ::Proxy::Log

      get '/roles' do
        RolesReader.list_roles.to_json
      end

      get '/roles/variables' do
        variables = {}
        RolesReader.list_roles.each do |role_name|
          variables.merge!(extract_variables(role_name))
        rescue ReadVariablesException => e
          # skip what cannot be parsed
          logger.error e
        end
        variables.to_json
      end

      get '/roles/:role_name/variables' do |role_name|
        extract_variables(role_name).to_json
      rescue ReadVariablesException => e
        logger.error e
        {}.to_json
      end

      private

      def extract_variables(role_name)
        variables = {}
        role_name_parts = role_name.split('.')
        if role_name_parts.count == 3
          RolesReader.collections_paths.split(':').each do |path|
            variables[role_name] = VariablesExtractor
                                   .extract_variables("#{path}/ansible_collections/#{role_name_parts[0]}/#{role_name_parts[1]}/roles/#{role_name_parts[2]}") if variables[role_name].nil? || variables[role_name].empty?
          end
        else
          RolesReader.roles_path.split(':').each do |path|
            role_path = "#{path}/#{role_name}"
            if File.directory?(role_path)
              variables[role_name] ||= VariablesExtractor.extract_variables(role_path)
            end
          end
        end
        variables
      end
    end
  end
end
