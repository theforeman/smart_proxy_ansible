# frozen_string_literal: true

module Proxy
  module Ansible
    # Taken from Foreman core, this class creates an error code for any
    # exception
    class Exception < ::StandardError
      def initialize(message, *params)
        super()
        @message = message
        @params = params
      end

      def self.calculate_error_code(classname, message)
        return 'ERF00-0000' if classname.nil? || message.nil?

        basename = classname.split(':').last
        class_hash = Zlib.crc32(basename) % 100
        msg_hash = Zlib.crc32(message) % 10_000
        format 'ERF%<clshash>02d-%<msghash>04d', clshash: class_hash, msghash: msg_hash
      end

      def code
        @code ||= Exception.calculate_error_code(self.class.name, @message)
        @code
      end

      def message
        # make sure it works without gettext too
        translated_msg = @message % @params
        "#{code} [#{self.class.name}]: #{translated_msg}"
      end

      def to_s
        message
      end
    end

    class ReadConfigFileException < Proxy::Ansible::Exception; end

    class ReadRolesException < Proxy::Ansible::Exception; end

    class ReadVariablesException < Proxy::Ansible::Exception; end
  end
end
