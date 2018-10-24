module Proxy
  module Ansible
    # API endpoints. Most of the code should be calling other classes,
    # please keep the actual implementation of the endpoints outside
    # of this class.
    class Api < Sinatra::Base
      get '/roles' do
        RolesReader.list_roles.to_json
      end

      get '/roles/variables' do
        variables = {}
        RolesReader.list_roles.each do |role_name|
          variables[role_name] = extract_variables(role_name)[role_name]
        end
        variables.to_json
      end

      get '/roles/:role_name/variables' do |role_name|
        extract_variables(role_name).to_json
      end

      private

      def extract_variables(role_name)
        variables = {}
        RolesReader.roles_path.split(':').each do |path|
          variables[role_name] = VariablesExtractor
                                 .extract_variables("#{path}/#{role_name}")
        end
        variables
      end
    end
  end
end
