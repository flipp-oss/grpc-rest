# frozen_string_literal: true

require 'rspec'
require 'src/proto/grpc/testing/test_services_pb'

require_relative '../lib/base_interceptor'
require_relative './spec_helper'

RSpec.describe GrpcRest::BaseInterceptor do
  let(:rpc_service) { Grpc::Testing::TestService::Service.new }
  let(:rpc_desc) { Grpc::Testing::TestService::Service.rpc_descs.values.first}
  let(:message) { Grpc::Testing::SimpleRequest.new }

  describe '#fail!' do
    let(:error_message) { 'some message' }
    let(:error_code) { :invalid_argument }

    it 'fails properly' do
      request = Gruf::Controllers::Request.new(
        method_key: :UnaryCall,
        service: rpc_service,
        rpc_desc: rpc_desc,
        active_call: nil,
        message: message)
      interceptor = GrpcRest::BaseInterceptor.new(request, Gruf::Error.new)

      expect{ interceptor.fail!(error_code, error_message) }.to raise_error(GRPC::InvalidArgument) do |error|
        expect(error.message).to match(error_message)
        expect(error.code).to eq(GRPC::Core::StatusCodes::INVALID_ARGUMENT)
      end
    end
  end
end
