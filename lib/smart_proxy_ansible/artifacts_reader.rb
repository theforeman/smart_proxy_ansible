# frozen_string_literal: true

module Proxy::Ansible
  class ArtifactsReader
    Artifact = Struct.new(:path, :content, :keyword_init => true)

    def initialize(root)
      @root = root
      @counter = 1
    end

    def new_artifacts
      files = new_event_files
      return [] if files.empty?

      artifacts = files.map do |path, _number|
        Artifact.new(:path => path, :content => File.read(path))
      end
      @counter = files.last.last + 1
      artifacts
    end

    private

    def new_event_files
      event_directory = event_directory_path
      return [] unless event_directory

      files = Dir[File.join(event_directory, '*.json')].each_with_object([]) do |path, result|
        basename = File.basename(path)
        match = basename.match(/\A(\d+)/)
        next if basename.include?('partial') || !match

        result << [path, match[1].to_i]
      end
      files.select { |_path, number| number >= @counter }.sort_by(&:last)
    end

    def event_directory_path
      unless @uuid
        artifact_directory = Dir[File.join(@root, 'artifacts', '*')].first
        @uuid = File.basename(artifact_directory) if artifact_directory
      end
      File.join(@root, 'artifacts', @uuid, 'job_events') if @uuid
    end
  end
end
