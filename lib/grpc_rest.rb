require 'google/protobuf/well_known_types'
require 'grpc'
require 'grpc/core/status_codes'

module GrpcRest
  class << self

    def underscore(s)
      GRPC::GenericService.underscore(s)
    end

    # Gets a sub record from a proto. If it doesn't exist, initialize it and set it to the proto,
    # then return it.
    def sub_field(proto, name, parameters)
      existing = proto.public_send(name.to_sym)
      return existing if existing

      descriptor = proto.class.descriptor.to_a.find { |a| a.name == name }
      return nil if descriptor.nil?

      klass = descriptor.submsg_name.split('.').map(&:camelize).join('::').constantize
      params = klass.descriptor.to_a.map(&:name).to_h do |key|
        [key, parameters.delete(key)]
      end

      sub_record = klass.new(params)
      proto.public_send(:"#{name}=", sub_record)
      sub_record
    end

    def assign_value(proto, path, value)
      tokens = path.split('.')
      tokens[0...-1].each do |path_seg|
        proto = sub_field(proto, path_seg, {})
        return if proto.nil?
      end
      proto.public_send(:"#{tokens.last}=", value) if proto.respond_to?(:"#{tokens.last}=")
    end

    # https://stackoverflow.com/a/2158473/5199431
    def longest_common_substring(arr)
      return "" if arr.empty?

      result = 0
      first_val = arr[0]
      (0...first_val.length).each do |k|
        all_matched = true
        character = first_val[k]
        arr.each { |str| all_matched &= (character == str[k]) }
        break unless all_matched
        result += 1
      end
      first_val.slice(0, result)
    end

    def handle_enum_values(descriptor, value)
      names = descriptor.subtype.to_h.keys.map(&:to_s)
      prefix = longest_common_substring(names)
      if prefix.present? && !value.starts_with?(prefix)
        "#{prefix}#{value}"
      else
        value
      end
    end

    def map_proto_type(descriptor, val)
      if descriptor.subtype.is_a?(Google::Protobuf::EnumDescriptor)
        return handle_enum_values(descriptor, val)
      end

      case descriptor.type
      when *%i(int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32 sfixed64)
        return val.to_i
      when *%i(float double)
        return val.to_f
      when :bool
        return !!val
      end

      case descriptor.subtype&.name
      when 'google.protobuf.Struct'
        return Google::Protobuf::Struct.from_hash(val)
      when 'google.protobuf.Timestamp'
        if val.is_a?(Numeric)
          return Google::Protobuf::Timestamp.from_time(Time.at(val))
        else
          return Google::Protobuf::Timestamp.from_time(Time.new(val))
        end
      when 'google.protobuf.Value'
        return Google::Protobuf::Value.from_ruby(val)
      when 'google.protobuf.ListValue'
        return Google::Protobuf::ListValue.from_a(val)
      else
        return map_proto_record(descriptor.subtype, val)
      end
    end

    def map_proto_record(proto, params)
      proto.to_a.each do |descriptor|
        field = descriptor.name
        val = params[field]
        next if val.nil?

        if descriptor.label == :repeated
          params[field] = val.map { |v| map_proto_type(descriptor, v) }
        else
          params[field] = map_proto_type(descriptor, val)
        end
      end
      params
    end

    def init_request(request_class, params)
      map_proto_record(request_class.descriptor, params)
      request_class.decode_json(JSON.generate(params), ignore_unknown_fields: true)
    end

    def assign_params(request, param_hash, body_string, params)
      parameters = params.to_h.deep_dup
      # each instance of {variable} means that we set the corresponding param variable into the
      # Protobuf request
      # The variable pattern could have dots which indicate we need to drill into the request
      # to set it - e.g. {subrecord.foo} means we need to set the value of `request.subrecord.foo` to `params[:foo].`
      # We can also do simple wildcard replacement if there's a * - for example, {name=something-*}
      # means we should set `request.name` to "something-#{params[:name]}".
      param_hash.each do |entry|
        name_tokens = entry[:split_name]
        value_to_use = parameters.delete(name_tokens.last)
        if entry[:val]
          regex = entry[:val].tr('*', '')
          value_to_use = value_to_use.gsub(regex, '')
        end
        assign_value(request, entry[:name], value_to_use)
      end
      if body_string.present? && body_string != '*'
        # we need to "splat" the body parameters into the given sub-record rather than into the top-level.
        sub_record = sub_field(request, body_string, parameters)
      end
    end

    # Ported from https://github.com/grpc-ecosystem/grpc-gateway/blob/main/runtime/errors.go#L36
    def grpc_http_status(code)
      case code
      when GRPC::Core::StatusCodes::OK
        :ok
      when GRPC::Core::StatusCodes::CANCELLED
        499
      when GRPC::Core::StatusCodes::INVALID_ARGUMENT,
        GRPC::Core::StatusCodes::FAILED_PRECONDITION,
        GRPC::Core::StatusCodes::OUT_OF_RANGE
        :bad_request
      when GRPC::Core::StatusCodes::DEADLINE_EXCEEDED
        :gateway_timeout
      when GRPC::Core::StatusCodes::NOT_FOUND
        :not_found
      when GRPC::Core::StatusCodes::ALREADY_EXISTS, GRPC::Core::StatusCodes::ABORTED
        :conflict
      when GRPC::Core::StatusCodes::PERMISSION_DENIED
        :forbidden
      when GRPC::Core::StatusCodes::UNAUTHENTICATED
        :unauthorized
      when GRPC::Core::StatusCodes::RESOURCE_EXHAUSTED
        :too_many_requests
      when GRPC::Core::StatusCodes::UNIMPLEMENTED
        :not_implemented
      when GRPC::Core::StatusCodes::UNAVAILABLE
        :service_unavailable
      else
        :internal_server_error
      end
    end

    def error_msg(error)
      Rails.logger.error("#{error.message}, backtrace: #{error.backtrace.join("\n")}")
      if error.respond_to?(:code)
      {
          code: error.code,
          message: error.message,
          details: [
                    {
                      backtrace: error.backtrace
                    }
          ]
      }
      else
        {
            code: 3,
            message: "InvalidArgument: #{error.message}",
            details: [
                      {
                        backtrace: error.backtrace
                      }
            ]
        }
      end
    end

    def send_gruf_request(klass, service_obj, method, request)
      ref = service_obj.rpc_descs[method.classify.to_sym]
      handler = klass.new(
        method_key: method.to_sym,
        service: service_obj,
        rpc_desc: ref,
        active_call: nil,
        message: request
      )
      Gruf::Interceptors::Context.new(gruf_interceptors(request)).intercept! do
        handler.send(method.to_sym)
      end
    end

    # @param request [Google::Protobuf::AbstractMessage]
    # @return [Array<Gruf::Interceptors::Base>]
    def gruf_interceptors(request)
      error = Gruf::Error.new
      interceptors = Gruf.interceptors.prepare(request, error)
      interceptors.delete_if { |k| k.class.name.split('::').first == 'Gruf' }
      interceptors
    end

    def send_grpc_request(service, method, request)
      klass = service.constantize::Service.subclasses.first
      klass.new.public_send(method, request)
    end

    def get_response(service, method, request)
      if defined?(Gruf)
        service_obj = service.constantize::Service
        klass = ::Gruf::Controllers::Base.subclasses.find do |k|
          k.bound_service == service_obj
        end
        if klass
          return send_gruf_request(klass, service_obj, method, request)
        end
      end
      send_grpc_request(service, method, request)
    end

    def send_request(service, method, request, options={})
      response = get_response(service, method, request)
      if options[:emit_defaults]
        response.to_json(emit_defaults: true)
      else
        response
      end
    end
  end

end
