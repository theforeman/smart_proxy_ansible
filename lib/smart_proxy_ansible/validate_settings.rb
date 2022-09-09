# frozen_string_literal: true

module Proxy::Ansible
  class ValidateSettings < ::Proxy::PluginValidators::Base
    def validate!(settings)
      raise NotExistingWorkingDirException.new("Working directory does not exist") unless settings[:working_dir].nil? || File.directory?(File.expand_path(settings[:working_dir]))
    end
  end
end
