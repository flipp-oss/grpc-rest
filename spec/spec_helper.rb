# frozen_string_literal: true

require "action_controller/railtie"

class GrpcApp < Rails::Application
  initializer(:host_config) do
    Rails.application.config.hosts << "www.example.com"
  end
end
GrpcApp.initialize!

require 'rspec/rails'

loader = Zeitwerk::Loader.new
loader.push_dir('./spec')
loader.inflector.inflect('protoc-gen-openapiv2' => 'ProtocGenOpenapiv2')
loader.ignore("#{Rails.root}/spec/test_service_pb.rb")
loader.setup
require "#{Rails.root}/spec/test_service_pb.rb"

$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

RSpec.configure do |config|
  config.full_backtrace = true
  config.render_views

  config.mock_with(:rspec) do |mocks|
    mocks.yield_receiver_to_any_instance_implementation_blocks = true
    mocks.verify_partial_doubles = true
  end
end

require_relative '../protoc-gen-rails/testdata/base/app/controllers/my_service_controller'
Rails.application.routes.draw_paths.push("#{Rails.root}/protoc-gen-rails/testdata/base/config/routes")
Rails.application.routes.draw do
  draw(:grpc)
end
