module GrpcRest
  class << self

    # Gets a sub record from a proto. If it doesn't exist, initialize it and set it to the proto,
    # then return it.
    def sub_field(proto, name)
      existing = proto.public_send(name.to_sym)
      return existing if existing

      descriptor = proto.class.descriptor.to_a.find { |a| a.name == name }
      klass = descriptor.submsg_name.split('.').map(&:camelize).join('::').constantize
      sub_record = klass.new
      proto.public_send(:"#{name}=", sub_record)
      sub_record
    end

    def assign_value(proto, path, value)
      tokens = path.split('.')
      tokens[0...-1].each do |path_seg|
        proto = sub_field(proto, path_seg)
      end
      proto.public_send(:"#{tokens.last}=", value)
    end

    def assign_params(request, param_string, body_string, params)
      parameters = params.to_h.deep_dup
      # each instance of {variable} means that we set the corresponding param variable into the
      # Protobuf request
      # The variable pattern could have dots which indicate we need to drill into the request
      # to set it - e.g. {subrecord.foo} means we need to set the value of `request.subrecord.foo` to `params[:foo].`
      # We can also do simple wildcard replacement if there's a * - for example, {name=something-*}
      # means we should set `request.name` to "something-#{params[:name]}".
      param_string.scan(/\{(.*?)}/).each do |match|
        name, val = match[0].split('=')
        val = '*' if val.blank?
        name_tokens = name.split('.')
        assign_value(request, name, val.gsub('*', parameters.delete(name_tokens.last)))
      end
      if body_string.present? && body_string != '*'
        # we need to "splat" the body parameters into the given sub-record rather than into the top-level.
        sub_record = sub_field(request, body_string)
        sub_record.class.descriptor.to_a.map(&:name).each do |key|
          sub_record.public_send(:"#{key}=", parameters.delete(key))
        end
      end

      # assign remaining parameters
      parameters.except('action', 'controller').each do |k, v|
        assign_value(request, k, v)
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

    def send_request(service, method, request)
      service_obj = service.constantize::Service
      response = if defined?(Gruf)
        klass = ::Gruf::Controllers::Base.subclasses.find do |k|
          k.bound_service == service_obj
        end
        ref = service_obj.rpc_descs[method.classify.to_sym]
        handler = klass.new(
          method_key: method.to_sym,
          service: service_obj,
          rpc_desc: ref,
          active_call: nil,
          message: request
        )
        handler.send(method.to_sym)
                 else
                   raise 'Non-gruf grpc not implemented yet!'
      end
      response.to_h
    end
  end

end
