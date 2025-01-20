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
        @job_check_mode = action_input[:job_check_mode]
        @diff_mode = action_input[:diff_mode]
        @tags = action_input[:tags]
        @tags_flag = action_input[:tags_flag]
        @passphrase = action_input['secrets']['key_passphrase']
        @execution_timeout_interval = action_input[:execution_timeout_interval]
        @cleanup_working_dirs = action_input.fetch(:cleanup_working_dirs, true)
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
        @counter ||= 1
        @uuid ||= if (f = Dir["#{@root}/artifacts/*"].first)
                    File.basename(f)
                  end
        return unless @uuid
        job_event_dir = File.join(@root, 'artifacts', @uuid, 'job_events')
        loop do
          files = Dir["#{job_event_dir}/*.json"].map do |file|
            num = File.basename(file)[/\A\d+/].to_i unless file.include?('partial')
            [file, num]
          end
          files_with_nums = files.select { |(_, num)| num && num >= @counter }.sort_by(&:last)
          break if files_with_nums.empty?
          logger.debug("[foreman_ansible] - processing event files: #{files_with_nums.map(&:first).inspect}}")
          files_with_nums.map(&:first).each { |event_file| handle_event_file(event_file) }
          @counter = files_with_nums.last.last + 1
        end
      end

      def handle_event_file(event_file)
        logger.debug("[foreman_ansible] - parsing event file #{event_file}")
        begin
          event = JSON.parse(File.read(event_file))
          if (hostname = hostname_for_event(event))
            handle_host_event(hostname, event)
          else
            handle_broadcast_data(event)
          end
          true
        rescue JSON::ParserError => e
          logger.error("[foreman_ansible] - Error parsing runner event at #{event_file}: #{e.class}: #{e.message}")
          logger.debug(e.backtrace.join("\n"))
        end
      end

      def hostname_for_event(event)
        hostname = event.dig('event_data', 'host') || event.dig('event_data', 'remote_addr')
        return nil if hostname.nil? || hostname.empty?

        unless @targets.key?(hostname)
          logger.warn("handle_host_event: unknown host #{hostname} for event '#{event['event']}', broadcasting")
          return nil
        end
        hostname
      end

      def handle_host_event(hostname, event)
        log_event("for host: #{hostname.inspect}", event)
        publish_data_for(hostname, event['stdout'] + "\n", 'stdout') if event['stdout']
        case event['event']
        when 'runner_on_ok'
          publish_exit_status_for(hostname, 0) if @exit_statuses[hostname].nil?
        when 'runner_on_unreachable'
          publish_exit_status_for(hostname, 1)
        when 'runner_on_failed'
          publish_exit_status_for(hostname, 2) if event.dig('event_data', 'ignore_errors').nil?
        end
      end

      def handle_broadcast_data(event)
        log_event("broadcast", event)
        if event['event'] == 'playbook_on_stats'
          failures = event.dig('event_data', 'failures') || {}
          unreachable = event.dig('event_data', 'dark') || {}
          rescued = event.dig('event_data', 'rescued') || {}
          header, *rows = event['stdout'].strip.lines.map(&:rstrip)
          # #lines strips the leading newline that precedes the header
          broadcast_data("\n" + header + "\n", 'stdout')

          inventory_hosts = @outputs.keys.select { |key| key.is_a? String }
          rows.each do |row|
            host = inventory_hosts.find { |host| row =~ /#{host}/ }
            line = row + "\n"
            unless host
              broadcast_data(line, 'stdout')
              next
            end

            publish_data_for(host, line, 'stdout')

            # If the task has been rescued, it won't consider a failure
            if @exit_statuses[host].to_i != 0 && failures[host].to_i <= 0 && unreachable[host].to_i <= 0 && rescued[host].to_i > 0
              publish_exit_status_for(host, 0)
            end
          end
        else
          broadcast_data(event['stdout'] + "\n", 'stdout')
        end

        # If the run ends early due to an error - fail all other tasks
        if event['event'] == 'error'
          @outputs.keys.select { |key| key.is_a? String }.each do |host|
            @exit_statuses[host] = 4 if @exit_statuses[host].to_i == 0
          end
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
        cmd_args = [tags_cmd, check_cmd, diff_cmd].reject(&:empty?)
        return nil unless cmd_args.any?
        cmd_args.join(' ')
      end

      def tags_cmd
        flag = @tags_flag == 'include' ? '--tags' : '--skip-tags'
        @tags.empty? ? '' : "#{flag} '#{Array(@tags).join(',')}'"
      end

      def check_cmd
        if check_mode? || job_check_mode?
          '"--check"'
        else
          ''
        end
      end

      def diff_cmd
        diff_mode? ? '"--diff"' : ''
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

      def job_check_mode?
        @job_check_mode == true
      end

      def diff_mode?
        @diff_mode == true
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
            'ansible_password' => secrets['ssh_password'] || per_host['ansible_password'],
            'ansible_become_password' => secrets['effective_user_password'] || per_host['ansible_become_password']
          }
          inventory['all']['hosts'][host].update(new_secrets)
        end

        inventory
      end
    end
  end
end
