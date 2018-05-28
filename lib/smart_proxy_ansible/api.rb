require 'foreman_ansible_core'

module Proxy
  module Ansible
    class Api < Sinatra::Base
      get '/roles' do
        ::ForemanAnsibleCore::RolesReader.list_roles.to_json
      end

      get '/roles/variables' do
        variables = {}
        ::ForemanAnsibleCore::RolesReader.list_roles.each do |role_name|
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
        ::ForemanAnsibleCore::RolesReader.roles_path.split(':').each do |path|
          variables[role_name] = ::ForemanAnsibleCore::VariablesExtractor.
            extract_variables("#{path}/#{role_name}")
        end
        variables
      end
    end
  end
end
