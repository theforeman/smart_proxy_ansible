module Proxy
  module Ansible
    # Implements the logic needed to read the roles and associated information
    class VariablesExtractor
      class << self
        def extract_variables(role_path)
          role_files = Dir.glob("#{role_path}/defaults/**/*.yml") +
            Dir.glob("#{role_path}/defaults/**/*.yaml")
          # not anything matching item, }}, {{, ansible_hostname or 'if'
          variables = role_files.map do |role_file|
            candidates = File.read(role_file).scan(/{{(.*?)}}/).select do |param|
              param.first.scan(/item/) == [] && param.first.scan(/if/) == []

            end.flatten
            # Sometimes inside the {{ }} there's a OR condition. In such a case,
            # let's split and choose possible variables (variables cannot contain
            # parenthesis)

            candidates.map do |variable|
              variable.split('|').map(&:strip).select do |var|
                !var.include?('(') && # variables are not parenthesis
                  !var.include?('[') && # variables are not arrays
                  !var.include?('.') && # variables are not objects
                  !var.include?("'") # variables are not plain strings
              end
            end unless candidates.nil?
          end.compact.flatten.uniq.map(&:strip)
          variables
        end
      end
    end
  end
end
