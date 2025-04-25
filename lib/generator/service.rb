# frozen_string_literal: true

require_relative 'method'

module ProtocGenRails
  class Service
    attr_accessor :methods

    # @param service_proto [Google::Protobuf::ServiceDescriptorProto]
    # @param package [String]
    def initialize(service_proto, package)
      # see https://github.com/protocolbuffers/protobuf/issues/21091 for why this is needed
      # this will return a Google::Protobuf::ServiceDescriptor
      @service = Google::Protobuf::DescriptorPool.generated_pool.lookup("#{package}.#{service_proto.name}")
      if @service.nil?
        ProtocGenRails::Output.exit_with_error("Could not find generated service: #{package}.#{service_proto.name}")
      end
      @methods = []
      @package = package
      @service.each do |m|
        # m is a Google::Protobuf::MethodDescriptor
        @methods.push(ProtocGenRails::Method.new(m))
      end
    end

    # @return [String]
    def name
      @service.name.split('.').map(&:camelcase).join('::').demodulize
    end

    # @return [String]
    def namespace
      @package.split('.').map(&:camelcase).join('::')
    end
  end
end
