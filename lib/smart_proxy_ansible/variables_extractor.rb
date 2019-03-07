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
            loaded_yaml = {}
            begin
              loaded_yaml = YAML.load_file(role_file)
            rescue Psych::SyntaxError
              raise ReadVariablesException.new "#{role_file} is not YAML file"
            end
            raise ReadVariablesException.new "Could not parse YAML file: #{role_file}" unless loaded_yaml.is_a? Hash
            memo.merge loaded_yaml
          end
        end
      end
    end
  end
end
