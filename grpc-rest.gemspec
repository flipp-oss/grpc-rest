# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'grpc_rest/version'

Gem::Specification.new do |spec|
  spec.name          = 'grpc-rest'
  spec.version       = GrpcRest::VERSION
  spec.authors       = ['Daniel Orner']
  spec.email         = ['daniel.orner@flipp.com']
  spec.summary       = 'Generate Rails controllers and routes from gRPC definitions.'
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency('google-protobuf', '>= 4.30.2')
  spec.add_runtime_dependency('grpc')
  spec.add_runtime_dependency('rails', '>= 6.0')

  spec.add_development_dependency('byebug')
  spec.add_development_dependency('gruf')
  spec.add_development_dependency('rspec-rails')
  spec.add_development_dependency('rspec-snapshot')
end
