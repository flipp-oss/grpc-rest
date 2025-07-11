require "action_mailer/railtie"
require 'generator/service'
require 'generator/controller'

class GrpcRest::Railtie < Rails::Railtie
  initializer 'grpc-rest' do
    Rails.configuration.after_initialize do
      grpc_services = GrpcRest.services
      if grpc_services.blank? && defined?(Gruf)
        grpc_services = ::Gruf::Controllers::Base.subclasses.map(&:bound_service)
      end
      grpc_services&.each do |s|
        service = GrpcRest::GeneratedService.new(s)
        GrpcRest.controller(service)
      end

    end
  end
end
