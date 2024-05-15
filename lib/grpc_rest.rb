require 'google/protobuf/well_known_types'
require 'grpc'

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

    def map_proto_type(proto, params)
      proto.to_a.each do |descriptor|
        field = descriptor.name
        val = params[field]
        next if val.nil?
        next if descriptor.subtype.is_a?(Google::Protobuf::EnumDescriptor)

        case descriptor.type
        when *%i(int32 int64 uint32 uint64 sint32 sint64 fixed32 fixed64 sfixed32 sfixed64)
          params[field] = val.to_i
        when *%i(float double)
          params[field] = val.to_f
        when :bool
          params[field] = !!val
        end

        case descriptor.subtype&.name
        when 'google.protobuf.Struct'
          params[field] = Google::Protobuf::Struct.from_hash(val)
        when 'google.protobuf.Timestamp'
          if val.is_a?(Numeric)
            params[field] = Google::Protobuf::Timestamp.from_time(Time.at(val))
          else
            params[field] = Google::Protobuf::Timestamp.from_time(Time.new(val))
          end
        when 'google.protobuf.Value'
          params[field] = Google::Protobuf::Value.from_ruby(val)
        when 'google.protobuf.ListValue'
          params[field] = Google::Protobuf::ListValue.from_a(val)
        else
          if params[field].is_a?(Array)
            params[field].each do |item|
              map_proto_type(descriptor.subtype, item)
            end
          else
            map_proto_type(descriptor.subtype, params[field])
          end
        end
      end
    end

    def init_request(request_class, params)
      map_proto_type(request_class.descriptor, params)
      request_class.new(params)
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

    def error_msg(error)
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

    def send_gruf_request(klass, service_obj, method, request)
      ref = service_obj.rpc_descs[method.classify.to_sym]
      handler = klass.new(
        method_key: method.to_sym,
        service: service_obj,
        rpc_desc: ref,
        active_call: nil,
        message: request
      )
      handler.send(method.to_sym)
    end

    def send_grpc_request(service, method, request)
      klass = service.constantize::Service.subclasses.first
      klass.new.public_send(method, request)
    end

    def send_request(service, method, request)
      if defined?(Gruf)
        service_obj = service.constantize::Service
        klass = ::Gruf::Controllers::Base.subclasses.find do |k|
          k.bound_service == service_obj
        end
        if klass
          return send_gruf_request(klass, service_obj, method, request).to_h
        end
      end
      send_grpc_request(service, method, request).to_h
    end
  end

end
