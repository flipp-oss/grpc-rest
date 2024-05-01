# grpc-rest
Generate Rails routes and controllers from protobuf files.

grpc-rest allows you to have a single codebase that serves both gRPC and classic Rails routes, with
a single handler (the gRPC handler) for both types of requests. It will add Rails routes to your
application that maps JSON requests to gRPC requests, and the gRPC response back to JSON. This is similar to 
[grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway), except that rather than proxying the gRPC requests, it simply uses the same handling code to serve both types of requests.

In order to actually accept both gRPC and REST calls, you will need to start your gRPC server in one process or thread,
and start your Rails server in a separate process or thread. They should both be listening on different ports (
the default port for Rails is 3000 and for gRPC is 9001).

With this, you get the automatic client code generation via Swagger and gRPC, the input validation that's automatic with gRPC, and the ease of use of tools like `curl` and Postman with REST.

## Components

`grpc-rest` comes with two main components:

* A protobuf generator plugin that generates Ruby files for Rails routes and controllers.
* The Rails library that powers these generated files.

The protobuf generator uses the same annotations as [grpc-gateway](https://github.com/grpc-ecosystem/grpc-gateway). This also gives you the benefit of being able to generate Swagger files by using protoc.

## Installation

First, download `protoc-gen-rails` from the releases page on the right and unzip it. Ensure the binary is somewhere in your PATH.

Then, add the following to your `Gemfile`:

```ruby
gem 'grpc-rest'
```

and run `bundle install`.

## Example

Here's an example protobuf file that defines a simple service:

```protobuf
syntax = "proto3";

package example;

import "google/api/annotations.proto";

message ExampleRequest {
  string name = 1;
}

message ExampleResponse {
  string message = 1;
}

service ExampleService {
  rpc GetExample (ExampleRequest) returns (ExampleResponse) {
    option (google.api.http) = {
      get: "/example/{name}"
    };
  }
}
```

First, you need to generate the Ruby files from this. You can do this with plain `protoc`, but it's much easier to handle if you use [buf](https://buf.build/). Here's an example `buf.gen.yaml` file:

```yaml
version: v1
managed:
  enabled: true
plugins:
  - plugin: buf.build/grpc/ruby:v1.56.2
    out: app/gen
    opt:
      - paths=source_relative
  - plugin: buf.build/protocolbuffers/ruby:v23.0
    out: app/gen
    opt:
      - paths=source_relative
  - name: rails
    out: .
```

Then, you can run `buf generate` to generate the Ruby files. This will generate:
* the Protobuf Ruby files for grpc, in `app/gen`
* A new route file, in `config/routes/grpc.rb`
* A new controller file, in `app/controllers`.

The generated route file will look like this:

```ruby
get "example/:name", to: "example#get_example"
```

and the generated controller will look like this:

```ruby
require 'services/example/example_services_pb'
class ExampleServiceController < ActionController::Base
  protect_from_forgery with: :null_session
  
  METHOD_PARAM_MAP = {

    "example" => [
       {name: "name", val: nil, split_name:["name"]},
			 ],
  }.freeze

	rescue_from StandardError do |e|
		render json: GrpcRest.error_msg(e)
	end

	def example
	  grpc_request = Services::Example::ExampleRequest.new
	  GrpcRest.assign_params(grpc_request, "/example/{name}", "", request.parameters)
      render json: GrpcRest.send_request("Services::Example::ExampleService", "example", grpc_request)
  end

end
```

To power it on, all you have to do is add the following to your `config/routes.rb`:

```ruby
Rails.application.routes.draw do
  draw(:grpc) # Add this line
end
```
 
## Caveats

This gem does not currently support the full path expression capabilities of grpc-gateway or the Google [http proto](https://github.com/googleapis/googleapis/blob/master/google/api/http.proto). It only supports very basic single wildcard globbing (`*`). Contributions are welcome for more complex cases if they are needed.

## To Do

* Replace Go implementation with Ruby (+ executable) once [service and method lookup](https://github.com/protocolbuffers/protobuf/pull/15817) is released.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/flipp-oss/grpc-rest.

To regenerate Ruby protobuf code for tests, install the `grpc-tools` gem and run this from the base directory:

```
grpc_tools_ruby_protoc -I=./protoc-gen-rails/testdata --proto_path=./protoc-gen-rails/google-deps --ruby_out=./spec --grpc_out=./spec ./protoc-gen-rails/testdata/test_service.proto
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
