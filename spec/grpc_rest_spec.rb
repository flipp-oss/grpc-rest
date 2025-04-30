# See https://github.com/rspec/rspec-rails/issues/1596#issuecomment-834282306

require_relative './spec_helper'
require_relative './test_service_services_pb'

class ServerImpl < Testdata::MyService::Service
  def test(req)
    Testdata::TestResponse.new(some_int: 1, full_response: req.to_json)
  end

  def test_2(req)
    Testdata::TestResponse.new(some_int: 2, full_response: req.to_json)
  end

  def test_3(req)
    Testdata::TestResponse.new(some_int: 3, full_response: req.to_json)
  end

  def test_4(req)
    Testdata::TestResponse.new(some_int: 4, full_response: req.to_json)
  end
end

RSpec.describe MyServiceController, type: :request do

  describe 'using get' do
    it 'should be successful' do
      get "/test/blah/xyz?test_id=abc"
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 1,
                                           'fullResponse' => %({"testId":"abc","foobar":"xyz"}),
                                           "ignoredKey" => ''
                                         })
    end
  end

  describe 'using body parameter' do
    it "should be successful" do
      params = {
        sub_id: "id1",
        another_id: "id2"
      }

      post '/test2?test_id=abc&foobar=xyz&timestamp_field=2024-04-03+01:02:03+UTC', params: params, as: :json
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 2,
                                           'fullResponse' => %({"testId":"abc","foobar":"xyz","secondRecord":{"subId":"id1","anotherId":"id2"},"timestampField":"2024-04-03T01:02:03Z"})
                                         })
    end

  end

  describe 'using sub-record splat' do
    it 'should be successful' do
      post '/test3/xyz?test_id=abc'
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 3,
                                           'fullResponse' => %({"testId":"abc","subRecord":{"subId":"xyz"}})
                                         })
    end
  end

  describe 'full body splat' do
    let(:params) do
      {
        test_id: 'abc',
        repeated_float: [1.0, 2.0],
        some_int: "65",
        foobar: 'xyz',
        repeated_string: ['W', 'T', 'F'],
        map_field: {
          'foo' => {
            sub_id: 'id5',
            another_id: 'id6'
          }
        },
        sub_record: {
          sub_id: 'id1',
          another_id: 'id2'
        },
        second_record: {
          sub_id: 'id3',
          another_id: 'id4'
        },
        struct_field: {
          "str_key": "val",
          "int_key": 123,
          "bool_key": true,
          "nil_key": nil,
          "list_key": [
                       {
                         "inner_key": "inner_val"
                       }
                     ]
        },
        list_value: ['F', 'Y', 'I'],
        bare_value: 45,
        timestamp_field: '2024-04-03 01:02:03 UTC',
        some_enum: 'TEST_ENUM_FOO'
      }
    end

    it 'should be successful' do
      post '/test4', params: params, as: :json
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 4,
                                           'fullResponse' => %({"testId":"abc","foobar":"xyz","repeatedString":["W","T","F"],"subRecord":{"subId":"id1","anotherId":"id2"},"secondRecord":{"subId":"id3","anotherId":"id4"},"structField":{"bool_key":true,"str_key":"val","nil_key":null,"list_key":[{"inner_key":"inner_val"}],"int_key":123},"timestampField":"2024-04-03T01:02:03Z","listValue":["F","Y","I"],"bareValue":45,"someInt":65,"someEnum":"TEST_ENUM_FOO","repeatedFloat":[1,2],"mapField":{"foo":{"subId":"id5","anotherId":"id6"}}})
                                         })
    end

    it 'should be successful without the enum prefix' do
      params[:some_enum] = 'FOO'
      post '/test4', params: params, as: :json
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 4,
                                           'fullResponse' => %({"testId":"abc","foobar":"xyz","repeatedString":["W","T","F"],"subRecord":{"subId":"id1","anotherId":"id2"},"secondRecord":{"subId":"id3","anotherId":"id4"},"structField":{"bool_key":true,"str_key":"val","nil_key":null,"list_key":[{"inner_key":"inner_val"}],"int_key":123},"timestampField":"2024-04-03T01:02:03Z","listValue":["F","Y","I"],"bareValue":45,"someInt":65,"someEnum":"TEST_ENUM_FOO","repeatedFloat":[1,2],"mapField":{"foo":{"subId":"id5","anotherId":"id6"}}})
                                         })
    end
  end

  describe 'numeric timestamp' do
    it 'should be successful' do
      params = {
        timestamp_field: 1712692452
      }
      post "/test4", params: params, as: :json
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 4,
                                           'fullResponse' => %({"timestampField":"2024-04-09T19:54:12Z"})
                                         })
    end
  end

  describe 'array of sub-records' do
    it 'should be successful' do
      params = {
        sub_records: [{
          sub_id: 'id1',
          another_id: 'id2'
        }]
      }

      post '/test4', params:, as: :json
      expect(response).to be_successful
      expect(response.parsed_body).to eq({
                                           'someInt' => 4,
                                           'fullResponse' => %({"subRecords":[{"subId":"id1","anotherId":"id2"}]})
                                         })
    end
  end
end
