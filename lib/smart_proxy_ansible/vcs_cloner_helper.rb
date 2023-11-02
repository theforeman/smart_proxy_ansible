# frozen_string_literal: true

module Proxy
  module Ansible
    # Implements VCS-Cloning logic and helper functions
    class VcsClonerHelper
      class << self
        def repo_path(role_name)
          @base_path ||= Pathname(Proxy::Ansible::Plugin.settings[:mutable_roles_path])
          @base_path.join(role_name)
        end

        def correct_repo_info(repo_info)
          %w[vcs_url name ref].all? { |param| repo_info.key?(param) }
        end

        def role_exists(role_name)
          repo_path(role_name).exist?
        end

        def install_role(repo_info)
          git = Git.init(repo_path(repo_info['name']))
          git.add_remote('origin', repo_info['vcs_url'])
          git.fetch
          git.checkout(repo_info['ref'])
        end

        def update_role(repo_info)
          git = Git.open(repo_path(repo_info['name']))
          git.remove_remote('origin')
          git.add_remote('origin', repo_info['vcs_url'])
          git.fetch
          git.checkout(repo_info['ref'])
        end

        def delete_role(role_name)
          FileUtils.rm_r repo_path(role_name)
        end
      end
    end
  end
end
