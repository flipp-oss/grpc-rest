# frozen_string_literal: true

require 'gruf'

module GrpcRest
    # This is a monkey-patch that fixes an issue we were having with using the fail! method in
    # interceptors where an active call was not instantiated yet.
    # Basically, we overloaded this function: https://github.com/bigcommerce/gruf/blob/main/lib/gruf/errors/helpers.rb#L34
  class BaseInterceptor < ::Gruf::Interceptors::ServerInterceptor
    def fail!(error_code, _app_code, message = 'unknown error', metadata = {})
      raise grpc_error(error_code, message.to_s, metadata)
    end

    private

    # Ported from https://github.com/flipp-oss/grpc-rest/blob/main/lib/grpc_rest.rb#L142
    def grpc_error(error_code, message, metadata)
      case error_code
      when :ok
        GRPC::Ok.new(message, metadata)
      when 499
        GRPC::Cancelled.new(message, metadata)
      when :bad_request, :invalid_argument
        GRPC::InvalidArgument.new(message, metadata)
      when :gateway_timeout
        GRPC::DeadlineExceeded.new(message, metadata)
      when :not_found
        GRPC::NotFound.new(message, metadata)
      when :conflict
        GRPC::AlreadyExists.new(message, metadata)
      when :forbidden
        GRPC::PermissionDenied.new(message, metadata)
      when :unauthorized
        GRPC::Unauthenticated.new(message, metadata)
      when :too_many_requests
        GRPC::ResourceExhausted.new(message, metadata)
      when :not_implemented
        GRPC::Unimplemented.new(message, metadata)
      when :service_unavailable
        GRPC::Unavailable.new(message, metadata)
      else
        GRPC::Internal.new(message, metadata)
      end
    end
  end
end
