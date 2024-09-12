require_relative './spec_helper'
require_relative './test_service_services_pb'
require 'gruf'

class GrufServerImpl < Gruf::Controllers::Base

  bind ::Testdata::MyService::Service

  def test
    Testdata::TestResponse.new(some_int: 1, full_response: request.message.to_json)
  end

  def test_2
    Testdata::TestResponse.new(some_int: 2, full_response: request.message.to_json)
  end

  def test_3
    Testdata::TestResponse.new(some_int: 3, full_response: request.message.to_json)
  end

  def test_4
    Testdata::TestResponse.new(some_int: 4, full_response: request.message.to_json)
  end

  cattr_accessor :intercepted
end

class TestInterceptor < ::Gruf::Interceptors::ServerInterceptor
  def call
    GrufServerImpl.intercepted = true
    yield
  end
end

Gruf::Server.new.add_interceptor(TestInterceptor, option_foo: 'value 123')

RSpec.describe MyServiceController, type: :request do
  describe 'using get' do
    it 'should be successful and call interceptors' do
      GrufServerImpl.intercepted = false
      get "/test/blah/xyz?test_id=abc"
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 1,
                                           'fullResponse' => %({"testId":"abc","foobar":"xyz"}),
                                           "ignoredKey" => ''
                                         })
      expect(GrufServerImpl.intercepted).to eq(true)
    end
  end
end
