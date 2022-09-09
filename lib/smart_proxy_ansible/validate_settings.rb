# frozen_string_literal: true

module Proxy::Ansible
  class ValidateSettings < ::Proxy::PluginValidators::Base
    def validate!(settings)
      return if settings[:working_dir].nil? || File.directory?(File.expand_path(settings[:working_dir]))

      raise NotExistingWorkingDirException, "Working directory does not exist"
    end
  end
end
