# frozen_string_literal: true

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

      get '/playbooks_names' do
        PlaybooksReader.playbooks_names.to_json
      end

      get '/playbooks/:playbooks_names?' do
        PlaybooksReader.playbooks(params[:playbooks_names]).to_json
      end

      private

      def extract_variables(role_name)
        variables = {}
        parts = role_name.split('.')
        if parts.count == 3
          ReaderHelper.collections_paths.split(':').each do |path|
            if variables[role_name].nil? || variables[role_name].empty?
              role_path = "#{path}/ansible_collections/#{parts[0]}/#{parts[1]}/roles/#{parts[2]}"
              variables[role_name] = VariablesExtractor.extract_variables(role_path)
            end
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
