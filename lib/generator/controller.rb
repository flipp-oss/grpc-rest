require 'google/protobuf'
require 'grpc'

module GrpcRestControllers
end

module GrpcRest
  class Controller < ActionController::Base
    protect_from_forgery with: :null_session

    rescue_from StandardError do |e|
      render json: GrpcRest.error_msg(e), status: :internal_server_error
    end
    rescue_from GRPC::BadStatus do |e|
      render json: GrpcRest.error_msg(e), status: GrpcRest.grpc_http_status(e.code)
    end
    rescue_from ActionDispatch::Http::Parameters::ParseError, Google::Protobuf::TypeError do |e|
      render json: GrpcRest.error_msg(e), status: :bad_request
    end
  end

  def self.controller(service)
    # e.g. GrpcRestControllers::MyServiceController
    klass = Class.new(GrpcRest::Controller) do
      service.methods.each do |method|
        # e.g. def my_service_test_method
      	define_method(method.name) do
          parameters = request.parameters.to_h.deep_transform_keys(&:underscore).
            except('controller', 'action', service.name.underscore)
          grpc_request = GrpcRest.init_request(method.request_type, parameters)
          GrpcRest.assign_params(grpc_request,
                                 method.path_info.map(&:to_h),
                                 method.option_body,
                                 request.parameters)
          render json: GrpcRest.send_request(service.service,
                                             method.name.underscore,
                                             grpc_request,
                                             method.rest_options,
                                             headers: request.headers)
        end
        Rails.application.routes.append do
          service_name = service.name.demodulize.underscore
          path = "grpc_rest_controllers/#{service_name}##{method.name.underscore}"
          # e.g. get '/my_service/test_method' => '/grpc_rest_controllers/my_service#test_method'
          self.send(method.http_method, method.sanitized_path => path)
        end
      end
    end
    GrpcRestControllers.const_set("#{service.name.demodulize}Controller", klass)
  end
end
