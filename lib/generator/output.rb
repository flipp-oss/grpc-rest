# frozen_string_literal: true

module ProtocGenRails
  module Output
    class << self
      # @param files [Array<FileResult>]
      # @return [String]
      def response(files)
        response = Google::Protobuf::Compiler::CodeGeneratorResponse.new
        response.supported_features = Google::Protobuf::Compiler::CodeGeneratorResponse::Feature::FEATURE_PROTO3_OPTIONAL
        files.each do |file|
          response.file << Google::Protobuf::Compiler::CodeGeneratorResponse::File.new(name: file.name,
                                                                                       content: file.content)
        end
        response.to_proto
      end

      # @param error [String]
      def exit_with_error(error)
        response = Google::Protobuf::Compiler::CodeGeneratorResponse.new
        response.error = error
        $stderr << "#{error}\n"
        $stdout << response.to_proto
        exit(1)
      end
    end
  end
end
