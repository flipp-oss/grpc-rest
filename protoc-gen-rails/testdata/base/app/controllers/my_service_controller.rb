
require 'grpc_rest'
require 'services/geo_admin/v1/test_services_pb'
class MyServiceController < ActionController::Base
  protect_from_forgery with: :null_session

	rescue_from Google::Protobuf::TypeError do |e|
		render json: GrpcRest.error_msg(e)
	end

	def test
	  grpc_request = Testdata::TestRequest.new
	  GrpcRest.assign_params(grpc_request, "/test/{blah=foobar/*}/{repeated_string}", "*", request.parameters)
    render json: GrpcRest.send_request("Testdata::MyService", "test", grpc_request)
  end

	def test_2
	  grpc_request = Testdata::TestRequest.new
	  GrpcRest.assign_params(grpc_request, "/test2", "second_record", request.parameters)
    render json: GrpcRest.send_request("Testdata::MyService", "test_2", grpc_request)
  end

	def test_3
	  grpc_request = Testdata::TestRequest.new
	  GrpcRest.assign_params(grpc_request, "/test3/{sub_record.sub_id}", "", request.parameters)
    render json: GrpcRest.send_request("Testdata::MyService", "test_3", grpc_request)
  end

end
