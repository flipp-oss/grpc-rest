# frozen_string_literal: true

require 'action_controller/railtie'
require 'grpc_rest'

require 'rspec/rails'
require 'rspec/snapshot'
require 'zeitwerk'

class GrpcApp < Rails::Application
  initializer(:host_config) do
    Rails.application.config.hosts << 'www.example.com'
  end
end

loader = Zeitwerk::Loader.new
loader.push_dir('./spec')
loader.inflector.inflect('protoc-gen-openapiv2' => 'ProtocGenOpenapiv2')
loader.ignore("#{Rails.root}/spec/*.rb")
loader.setup
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('gen', __dir__))

require "#{Rails.root}/spec/test_service_services_pb.rb"
require "#{Rails.root}/lib/base_interceptor.rb"

GrpcRest.services = [Testdata::MyService::Service]

GrpcApp.initialize!

RSpec.configure do |config|
  config.full_backtrace = true
  config.render_views

  config.mock_with(:rspec) do |mocks|
    mocks.yield_receiver_to_any_instance_implementation_blocks = true
    mocks.verify_partial_doubles = true
  end
end
