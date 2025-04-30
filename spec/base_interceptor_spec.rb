# frozen_string_literal: true

require_relative './spec_helper'
require 'src/proto/grpc/testing/test_services_pb'

RSpec.describe GrpcRest::BaseInterceptor, type: :class do
  let(:rpc_service) { Grpc::Testing::TestService::Service.new }
  let(:rpc_desc) { Grpc::Testing::TestService::Service.rpc_descs.values.first }
  let(:message) { Grpc::Testing::SimpleRequest.new }

  describe '#fail!' do
    let(:error_message) { 'some message' }
    let(:error_code) { :invalid_argument }

    it 'intercepts and raises the error' do
      request = Gruf::Controllers::Request.new(
        method_key: :UnaryCall,
        service: rpc_service,
        rpc_desc: rpc_desc,
        active_call: nil,
        message: message
      )
      interceptor = GrpcRest::BaseInterceptor.new(request, Gruf::Error.new)

      expect do
        interceptor.fail!(error_code, error_code, error_message)
      end.to raise_error(GRPC::InvalidArgument) do |error|
        expect(error.message).to match(error_message)
        expect(error.code).to eq(GRPC::Core::StatusCodes::INVALID_ARGUMENT)
      end
    end
  end
end
