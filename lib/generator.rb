# frozen_string_literal: true

require 'google/protobuf'
require 'erb'
require 'active_support/all'
require 'google/protobuf/well_known_types'
require 'pp'

require_relative 'generator/output'
require_relative 'generator/service'
require_relative 'generator/plugin_pb'

module ProtocGenRails
  FileResult = Struct.new(:name, :content)

  class << self
    # @param params [String]
    def require_directories(params)
      params.split(',').each do |param|
        key, value = param.split('=')
        next unless key == 'require'

        dirs = value.split(',')
        dirs.each do |v|
          $LOAD_PATH.unshift(v)
          dir = File.expand_path(v)
          Dir["#{dir}/**/*.rb"].each { |file| require file }
        end
      end
    end

    # @param input [String]
    # @return [String]
    def process(input)
      request = Google::Protobuf::Compiler::CodeGeneratorRequest.decode(input)
      files = []

      require_directories(request.parameter)

      services = []
      request.proto_file.each do |proto_file|
        next if request.file_to_generate.exclude?(proto_file.name)
        next if proto_file.service.none?

        proto_file.service.each do |service_descriptor|
          service = ProtocGenRails::Service.new(service_descriptor, proto_file.package)
          services.push(service)
          file = process_service(service)
          files.push(file) if file
        end
      end
      if files.any?
        route_output = route_file(services)
        files.push(route_output) if route_output
      end
      Output.response(files)
    end

    # @param service [ProtocGenRails::Service]
    # @return [FileResult]
    def process_service(service)
      content = parse_erb('controller', { service: service })
      FileResult.new(
        content: content,
        name: "app/controllers/#{service.name.underscore}_controller.rb"
      )
    end

    # @param services [Array<ProtocGenRails::Service>]
    # @return [FileResult]
    def route_file(services)
      content = parse_erb('grpc', { services: services })
      FileResult.new(
        name: 'config/routes/grpc.rb',
        content: content
      )
    end

    # @param filename [String]
    # @param data [Object]
    # @return [String]
    def parse_erb(filename, data)
      erb = File.read("#{__dir__}/generator/#{filename}.rb.erb")
      ERB.new(erb, trim_mode: '-').result_with_hash(data.to_h)
    end
  end
end
