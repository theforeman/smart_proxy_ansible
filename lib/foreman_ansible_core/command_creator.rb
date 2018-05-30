module ForemanAnsibleCore
  # Creates the actual command to be passed to foreman_tasks_core to run
  class CommandCreator
    attr_reader :command

    def initialize(inventory_file, playbook_file, options = {})
      @options = options
      @command = build_command('ansible-playbook', inventory_file, playbook_file)
    end

    private

    def build_command(cmd, inventory_file, playbook_file)
      command = [cmd, '-i', inventory_file]
      command << setup_verbosity if verbose?
      command.concat(['-T', @options[:timeout]]) unless @options[:timeout].nil?
      command << playbook_file
      command
    end

    def setup_verbosity
      verbosity_level = @options[:verbosity_level].to_i
      verbosity = '-'
      verbosity_level.times do
        verbosity += 'v'
      end
      verbosity
    end

    def verbose?
      verbosity_level = @options[:verbosity_level]
      # rubocop:disable Rails/Present
      !verbosity_level.nil? && !verbosity_level.empty? &&
        verbosity_level.to_i > 0
      # rubocop:enable Rails/Present
    end
  end
end
