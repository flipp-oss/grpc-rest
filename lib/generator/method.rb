# frozen_string_literal: true

module ProtocGenRails
  class Method
    PathInfo = Struct.new(:name, :val, :split_name)

    attr_accessor :http_method, :path, :path_info, :rest_options

    # @param proto_method [Google::Protobuf::MethodDescriptor]
    def initialize(proto_method)
      @method = proto_method
      @rest_options = extract_rest_options
      @options = extract_options
      @http_method, @path = method_and_path
      @path_info = extract_path_info
    end

    # @return [String]
    def option_body = @options&.body
    # @return [String]
    def name = @method.name.underscore

    # @return [String]
    def request_type
      @method.input_type.name.split('.').map(&:camelcase).join('::')
    end

    # @return [String]
    def sanitized_path
      path = @path
      re = /\{(.*?)}/
      matches = path.scan(re)
      matches.each do |match|
        repl = match[0]
        equal = repl.index('=')
        repl = repl[0...equal] if equal
        dot = repl.index('.')
        repl = repl[(dot + 1)..] if dot
        path = path.sub("{#{match[0]}}", "*#{repl}")
      end
      path
    end

    # @return [Google::Api::HttpRule]
    def extract_options
      return nil if @method.options.nil?

      extension = Google::Protobuf::DescriptorPool.generated_pool.lookup('google.api.http')
      extension.get(@method.options)
    end

    # @return [Hash]
    def extract_rest_options
      return nil if @method.options.nil?

      extension = Google::Protobuf::DescriptorPool.generated_pool
                                                  .lookup('grpc.gateway.protoc_gen_openapiv2.options.openapiv2_operation')
      result = extension.get(@method.options)
      return {} if result.nil?

      emit_defaults = result.extensions['x-grpc-rest-emit-defaults']&.bool_value || false
      {
        emit_defaults: emit_defaults
      }
    end

    # @return [String, String]
    def method_and_path
      return if @options.nil?

      if @options.pattern == :custom
        [@options.custom.kind, @options.custom.path]
      else
        [@options.pattern, @options.send(@options.pattern)]
      end
    end

    # @return [PathInfo]
    def extract_path_info
      @path.scan(/\{(.*?)}/).map do |match|
        name = match[0]
        val = ''
        equal = name.index('=')
        if equal
          val = name[equal..]
          name = name[0..equal - 1]
        end
        PathInfo.new(
          name: name,
          val: val,
          split_name: name.split('.')
        )
      end
    end
  end
end
