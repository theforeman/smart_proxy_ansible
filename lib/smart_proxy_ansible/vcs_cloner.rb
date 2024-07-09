# frozen_string_literal: true

require_relative 'vcs_cloner_helper'
require 'net/http'

module Proxy
  include ::Proxy::Log

  module Ansible
    Response = Struct.new(:status, :payload)

    # VCSCloner. This class performs cloning and updating of Ansible-Roles sourced from Git
    class VCSCloner
      class << self
        # Queries metadata about a given repository.
        # Requires parameter "vcs_url"
        # Returns 200 and the data if the query was successful
        # Returns 400 if a parameter is unfulfilled or invalid repo-info was provided
        def repo_information(payload)
          return Response.new(400, 'Check parameters') unless payload.key? 'vcs_url'

          vcs_url = payload['vcs_url']
          remote = Git.ls_remote(vcs_url).slice('head', 'branches', 'tags')
          remote['vcs_url'] = vcs_url
          Response.new(200, remote)
        rescue Git::GitExecuteError => e
          Response.new(400, "Git Error: #{e}")
        end

        # Returns an array of installed roles
        # Uses RolesReader.list_roles
        def list_installed_roles
          Response.new(200, RolesReader.list_roles)
        end

        # Clones a new role from the provided information.
        # Requires hash with keys "vcs_url", "name" and "ref"
        # Returns 201 if a role was created
        # Returns 400 if a parameter is unfulfilled or invalid repo-info was provided
        # Returns 409 if a role with "name" already exists
        def install(repo_info)
          return Response.new(400, 'Check parameters') unless VcsClonerHelper.correct_repo_info(repo_info)

          if VcsClonerHelper.role_exists repo_info['name']
            return Response.new(409,
                                "Role \"#{repo_info['name']}\" already exists.")
          end

          begin VcsClonerHelper.install_role repo_info
                Response.new(201, "Role \"#{repo_info['name']}\" has been created.")
          rescue Git::GitExecuteError => e
            Response.new(400, "Git Error: #{e}")
          end
        end

        # Updates a role with the provided information.
        # Installs a role if it does not yet exist
        # Requires hash with keys "vcs_url", "name" and "ref"
        # Returns 200 if a role was updated
        # Returns 201 if a role was created
        # Returns 400 if a parameter is unfulfilled or invalid repo-info was provided
        def update(repo_info)
          return Response.new(400, 'Check parameters') unless VcsClonerHelper.correct_repo_info repo_info

          begin
            if VcsClonerHelper.role_exists repo_info['name']
              VcsClonerHelper.update_role repo_info
              Response.new(200, "Role \"#{repo_info['name']}\" has been updated.")
            else
              VcsClonerHelper.install_role repo_info
              Response.new(201, "Role \"#{repo_info['name']}\" has been created.")
            end
          rescue Git::GitExecuteError => e
            Response.new(400, "Git Error: #{e}")
          end
        end

        # Deletes a role with the given name.
        # Installs a role if it does not yet exist
        # Requires parameter role_name
        # Returns 200 if a role was deleted / never existed
        # Returns 400 if a parameter is unfulfilled
        def delete(payload)
          return Response.new(400, 'Check parameters') unless payload.key? 'role_name'

          role_name = payload['role_name']
          unless VcsClonerHelper.role_exists role_name
            return Response.new(200,
                                "Role \"#{role_name}\" does not exist. Request ignored.")
          end

          VcsClonerHelper.delete_role role_name
          Response.new(200, "Role \"#{role_name}\" has been deleted.")
        end
      end
    end
  end
end
