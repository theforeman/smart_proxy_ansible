require 'yaml'

module Proxy
  module Ansible
    # Implements the logic needed to read the roles and associated information
    class VariablesExtractor
      class << self
        def extract_variables(role_path)
          role_files = Dir.glob("#{role_path}/defaults/**/*.yml") +
                       Dir.glob("#{role_path}/defaults/**/*.yaml")
          role_files.reduce({}) do |memo, role_file|
            loaded_yaml = load_role_file(role_file)

            memo.merge loaded_yaml
          end
        end

        def load_role_file(file)
          loaded_yaml = YAML.load_file(file)
          raise ReadVariablesException, "Could not parse YAML file: #{file}" unless loaded_yaml.is_a? Hash
          loaded_yaml
        rescue Psych::SyntaxError
          raise ReadVariablesException, "#{file} is not YAML file"
        end
      end
    end
  end
end
