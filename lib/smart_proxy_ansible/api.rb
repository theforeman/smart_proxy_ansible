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
          begin
            variables[role_name] = extract_variables(role_name)[role_name]
          rescue ReadVariablesException => e
            # skip what cannot be parsed
            logger.error e
          end
        end
        variables.to_json
      end

      get '/roles/:role_name/variables' do |role_name|
        begin
          extract_variables(role_name).to_json
        rescue ReadVariablesException => e
          logger.error e
          {}.to_json
        end
      end

      private

      def extract_variables(role_name)
        variables = {}
        RolesReader.roles_path.split(':').each do |path|
          role_path = "#{path}/#{role_name}"
          if File.directory?(role_path)
            variables[role_name] ||= VariablesExtractor
                                     .extract_variables(role_path)
          end
        end
        variables
      end
    end
  end
end
