
require 'grpc_rest'
class MyServiceController < ActionController::Base
  protect_from_forgery with: :null_session

	rescue_from StandardError do |e|
		render json: GrpcRest.error_msg(e)
	end
  METHOD_PARAM_MAP = {

    "test" => [
       {name: "blah", val: "foobar/*", split_name:["blah"]},
			 {name: "repeated_string", val: nil, split_name:["repeated_string"]},
			 ],

    "test_2" => [
       ],

    "test_3" => [
       {name: "sub_record.sub_id", val: nil, split_name:["sub_record","sub_id"]},
			 ],
}.freeze

	def test
    fields = Testdata::TestRequest.descriptor.to_a.map(&:name)
    grpc_request = Testdata::TestRequest.new(request.parameters.to_h.slice(*fields))
    GrpcRest.assign_params(grpc_request, METHOD_PARAM_MAP["test"], "*", request.parameters)
    render json: GrpcRest.send_request("Testdata::MyService", "test", grpc_request)
  end

	def test_2
    fields = Testdata::TestRequest.descriptor.to_a.map(&:name)
    grpc_request = Testdata::TestRequest.new(request.parameters.to_h.slice(*fields))
    GrpcRest.assign_params(grpc_request, METHOD_PARAM_MAP["test_2"], "second_record", request.parameters)
    render json: GrpcRest.send_request("Testdata::MyService", "test_2", grpc_request)
  end

	def test_3
    fields = Testdata::TestRequest.descriptor.to_a.map(&:name)
    grpc_request = Testdata::TestRequest.new(request.parameters.to_h.slice(*fields))
    GrpcRest.assign_params(grpc_request, METHOD_PARAM_MAP["test_3"], "", request.parameters)
    render json: GrpcRest.send_request("Testdata::MyService", "test_3", grpc_request)
  end

end
