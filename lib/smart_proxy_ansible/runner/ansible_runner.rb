require 'shellwords'
require 'yaml'

require 'smart_proxy_dynflow/runner/process_manager_command'
require 'smart_proxy_dynflow/runner/base'
require 'smart_proxy_dynflow/runner/parent'
module Proxy::Ansible
  module Runner
    class AnsibleRunner < ::Proxy::Dynflow::Runner::Parent
      include ::Proxy::Dynflow::Runner::ProcessManagerCommand
      attr_reader :execution_timeout_interval

      # To make this overridable in development
      ENVIRONMENT_WRAPPER = ENV['SMART_PROXY_ANSIBLE_ENVIRONMENT_WRAPPER'] || '/usr/libexec/foreman-proxy/ansible-runner-environment'

      def initialize(input, suspended_action:, id: nil)
        super input, :suspended_action => suspended_action, :id => id
        @inventory = rebuild_secrets(rebuild_inventory(input), input)
        action_input = input.values.first[:input][:action_input]
        @playbook = action_input[:script]
        @root = working_dir
        @verbosity_level = action_input[:verbosity_level]
        @rex_command = action_input[:remote_execution_command]
        @check_mode = action_input[:check_mode]
        @tags = action_input[:tags]
        @tags_flag = action_input[:tags_flag]
        @passphrase = action_input['secrets']['key_passphrase']
        @execution_timeout_interval = action_input[:execution_timeout_interval]
        @cleanup_working_dirs = action_input.fetch(:cleanup_working_dirs, true)
        @artifacts_processor = ArtifactsProcessor.new
      end

      def start
        prepare_directory_structure
        write_inventory
        write_playbook
        write_ssh_key if !@passphrase.nil? && !@passphrase.empty?
        start_ansible_runner
      end

      def run_refresh_output
        logger.debug('refreshing runner on demand')
        process_artifacts
        generate_updates
      end

      def timeout
        logger.debug('job timed out')
        super
      end

      def timeout_interval
        execution_timeout_interval
      end

      def kill
        ::Process.kill('SIGTERM', @process_manager.pid)
        publish_exit_status(2)
        @inventory['all']['hosts'].each { |hostname| @exit_statuses[hostname] = 2 }
        broadcast_data('Timeout for execution passed, stopping the job', 'stderr')
        close
      end

      def close
        super
        FileUtils.remove_entry(@root) if @tmp_working_dir && Dir.exist?(@root) && @cleanup_working_dirs
      end

      def publish_exit_status(status)
        process_artifacts
        super
        @targets.each_key { |host| publish_exit_status_for(host, @exit_statuses[host]) } if status != 0
      end

      def initialize_command(*command)
        super
        @process_manager.stdin.close unless @process_manager.done?
      end

      private

      def process_artifacts
        total_files = @artifacts_processor.process_artifacts(@root)

        while @artifacts_processor.last_file_num < total_files
          event = @artifacts_processor.get_next_event

          if @targets.key?(event.host)
            handle_host_event(event)
          else
            handle_broadcast_data(event)
          end
        end
      end

      def handle_host_event(event)
        log_event("for host: #{event.host.inspect}", event.json_event)
        publish_data_for(event.host, "#{event.output}\n", 'stdout') if event.output
        handle_exit_status(event)
      end

      def handle_exit_status(event)
        event.set_exit_status
        return if event.exit_status.nil?

        if event.exit_status == 0
          publish_exit_status_for(event.host, 0) if @exit_statuses[event.host].nil?
        else
          publish_exit_status_for(event.host, event.exit_status)
        end
      end

      def handle_broadcast_data(event)
        logger.warn("handle_host_event: unknown host #{event.host} for event '#{event.type}', broadcasting")
        log_event("broadcast", event.json_event)

        if event.type == 'playbook_on_stats'
          process_playbook_stats_event(event)
        else
          broadcast_data(event.output + "\n", 'stdout')
        end

        fail_all_other_tasks if event.type == 'error'
      end

      def process_playbook_stats_event(event)
        event.parse_failures
        header, *rows = event.output.strip.lines.map(&:chomp)

        @outputs.keys.select { |key| key.is_a? String }.each do |host|
          line = rows.find { |row| row =~ /#{host}/ }
          publish_data_for(host, [header, line].join("\n"), 'stdout')

          # If the task has been rescued, it won't consider a failure
          if @exit_statuses[host].to_i != 0 && event.has_failures_for_host(host)
            publish_exit_status_for(host, 0)
          end
        end
      end

      def fail_all_other_tasks
        # If the run ends early due to an error - fail all other tasks
        @outputs.keys.select { |key| key.is_a? String }.each do |host|
          @exit_statuses[host] = 4 if @exit_statuses[host].to_i == 0
        end
      end

      def write_inventory
        File.open(File.join(@root, 'inventory', 'hosts.json'), 'w') do |file|
          file.chmod(0o0640)
          file.write(JSON.dump(@inventory))
        end
      end

      def write_playbook
        File.write(File.join(@root, 'project', 'playbook.yml'), @playbook)
      end

      def write_ssh_key
        key_path = File.join(@root, 'env', 'ssh_key')
        File.symlink(File.expand_path(Proxy::RemoteExecution::Ssh::Plugin.settings[:ssh_identity_key_file]), key_path)

        passwords_path = File.join(@root, 'env', 'passwords')
        # here we create a secrets file for ansible-runner, which uses the key as regexp
        # to match line asking for password, given the limitation to match only first 100 chars
        # and the fact the line contains dynamically created temp directory, the regexp
        # mentions only things that are always there, such as artifacts directory and the key name
        secrets = YAML.dump({ "for.*/artifacts/.*/ssh_key_data:" => @passphrase })
        File.write(passwords_path, secrets, perm: 0o600)
      end

      def start_ansible_runner
        env = {}
        env['FOREMAN_CALLBACK_DISABLE'] = '1' if @rex_command
        env['SMART_PROXY_ANSIBLE_ENVIRONMENT_FILE'] = Proxy::Ansible::Plugin.settings[:ansible_environment_file]
        command = ['ansible-runner', 'run', @root, '-p', 'playbook.yml']
        command << '--cmdline' << cmdline unless cmdline.nil?
        command << verbosity if verbose?

        initialize_command(env, ENVIRONMENT_WRAPPER, *command)
        logger.debug("[foreman_ansible] - Running command '#{command.join(' ')}'")
      end

      def cmdline
        cmd_args = [tags_cmd, check_cmd].reject(&:empty?)
        return nil unless cmd_args.any?
        cmd_args.join(' ')
      end

      def tags_cmd
        flag = @tags_flag == 'include' ? '--tags' : '--skip-tags'
        @tags.empty? ? '' : "#{flag} '#{Array(@tags).join(',')}'"
      end

      def check_cmd
        check_mode? ? '"--check"' : ''
      end

      def verbosity
        '-' + 'v' * @verbosity_level.to_i
      end

      def verbose?
        @verbosity_level.to_i.positive?
      end

      def check_mode?
        @check_mode == true && @rex_command == false
      end

      def prepare_directory_structure
        inner = %w[inventory project env].map { |part| File.join(@root, part) }
        ([@root] + inner).each do |path|
          FileUtils.mkdir_p path
        end
      end

      def log_event(description, event)
        # TODO: replace this ugly code with block variant once https://github.com/Dynflow/dynflow/pull/323
        # arrives in production
        logger.debug("[foreman_ansible] - handling event #{description}: #{JSON.pretty_generate(event)}") if logger.level <= ::Logger::DEBUG
      end

      # Each per-host task has inventory only for itself, we must
      # collect all the partial inventories into one large inventory
      # containing all the hosts.
      def rebuild_inventory(input)
        action_inputs = input.values.map { |hash| hash[:input][:action_input] }
        inventories = action_inputs.map { |hash| hash[:ansible_inventory] }
        host_vars = inventories.map { |i| i['_meta']['hostvars'] }.reduce({}) do |acc, hosts|
          hosts.reduce(acc) do |inner_acc, (hostname, vars)|
            vars[:ansible_ssh_private_key_file] ||= Proxy::RemoteExecution::Ssh::Plugin.settings[:ssh_identity_key_file]
            inner_acc.merge(hostname => vars)
          end
        end

        { 'all' => { 'hosts' => host_vars,
                     'vars' => inventories.first['all']['vars'] } }
      end

      def working_dir
        return @root if @root
        dir = Proxy::Ansible::Plugin.settings[:working_dir]
        @tmp_working_dir = true
        if dir.nil?
          Dir.mktmpdir
        else
          Dir.mktmpdir(nil, File.expand_path(dir))
        end
      end

      def rebuild_secrets(inventory, input)
        input.each do |host, host_input|
          secrets = host_input['input']['action_input']['secrets']
          per_host = secrets['per-host'][host]

          new_secrets = {
            'ansible_password' => inventory['ssh_password'] || per_host['ansible_password'],
            'ansible_become_password' => inventory['effective_user_password'] || per_host['ansible_become_password']
          }
          inventory['all']['hosts'][host].update(new_secrets)
        end

        inventory
      end
    end
  end
end
