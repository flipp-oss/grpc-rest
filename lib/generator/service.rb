# frozen_string_literal: true

require_relative 'method'

module GrpcRest
  class GeneratedService
    attr_accessor :methods, :service

    # @param service [Class < GRPC::GenericService]
    def initialize(service)
      @service = service
      # this will return a Google::Protobuf::ServiceDescriptor
      @service_proto = Google::Protobuf::DescriptorPool.generated_pool.lookup(service.service_name)
      @methods = []
      @service_proto.each do |m|
        # m is a Google::Protobuf::MethodDescriptor
        @methods.push(GrpcRest::GeneratedMethod.new(m))
      end
    end

    # @return [String]
    def name
      @service_proto.name.split('.').map(&:camelcase).join('::').demodulize
    end
  end
end
