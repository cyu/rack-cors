require 'logger'

module Rack
  class Cors
    HEADER_KEY = 'X-Rack-Cors'

    def initialize(app, opts={}, &block)
      @app = app
      @debug_mode = !!opts[:debug]

      if logger = opts[:logger]
        if logger.respond_to? :call
          @logger_proc = opts[:logger]
        else
          @logger = logger
        end
      end

      if block_given?
        if block.arity == 1
          block.call(self)
        else
          instance_eval(&block)
        end
      end
    end

    def debug?
      @debug_mode
    end

    def allow(&block)
      all_resources << (resources = Resources.new)

      if block.arity == 1
        block.call(resources)
      else
        resources.instance_eval(&block)
      end
    end

    def call(env)
      env['HTTP_ORIGIN'] = 'file://' if env['HTTP_ORIGIN'] == 'null'
      env['HTTP_ORIGIN'] ||= env['HTTP_X_ORIGIN']

      add_headers = nil
      if env['HTTP_ORIGIN']
        debug(env) do
          [ 'Incoming Headers:',
            "  Origin: #{env['HTTP_ORIGIN']}",
            "  Access-Control-Request-Method: #{env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']}",
            "  Access-Control-Request-Headers: #{env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}"
            ].join("\n")
        end
        if env['REQUEST_METHOD'] == 'OPTIONS' and env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']
          if headers = process_preflight(env)
            debug(env) do
              "Preflight Headers:\n" +
                  headers.collect{|kv| "  #{kv.join(': ')}"}.join("\n")
            end
            return [200, headers, []]
          end
        else
          add_headers = process_cors(env)
        end
      elif debug?
        add_headers = { HEADER_KEY => "miss; no-origin-header" }
      end

      status, headers, body = @app.call env

      if add_headers
        headers = headers.merge(add_headers)

        # http://www.w3.org/TR/cors/#resource-implementation
        unless headers['Access-Control-Allow-Origin'] == '*'
          vary = headers['Vary']
          headers['Vary'] = ((vary ? vary.split(/,\s*/) : []) + ['Origin']).uniq.join(', ')
        end
      end

      [status, headers, body]
    end

    protected
      def debug(env, message = nil, &block)
        (@logger || select_logger(env)).debug(message, &block) if debug?
      end

      def select_logger(env)
        @logger = if @logger_proc
          logger_proc = @logger_proc
          @logger_proc = nil
          logger_proc.call

        elsif defined?(Rails) && Rails.logger
          Rails.logger

        elsif env['rack.logger']
          env['rack.logger']

        else
          ::Logger.new(STDOUT).tap { |logger| logger.level = ::Logger::Severity::DEBUG }
        end
      end

      def all_resources
        @all_resources ||= []
      end

      def process_preflight(env)
        resource, error = find_resource(env['HTTP_ORIGIN'], env['PATH_INFO'],env)
        if resource
          preflight = resource.process_preflight(env)
          preflight.merge!(HEADER_KEY => 'preflight-hit') if debug?
          preflight

        elif debug?
          { HEADER_KEY => ['preflight-miss', error].compact.join('; ') }
        end
      end

      def process_cors(env)
        resource, error = find_resource(env['HTTP_ORIGIN'], env['PATH_INFO'],env)
        if resource
          cors = resource.to_headers(env)
          cors.merge!(HEADER_KEY => 'hit') if debug?
          cors

        elif debug?
          { HEADER_KEY => ['miss', error].compact.join('; ') }
        end
      end

      def find_resource(origin, path, env)
        match = all_resources.detect { |r| r.allow_origin?(origin, env) }
        return [nil, 'no-origin-match'] unless match

        found = match.find_resource(path)
        return [nil, 'no-path-match'] unless found

        [found, nil]
      end

      class Resources
        def initialize
          @origins = []
          @resources = []
          @public_resources = false
        end

        def origins(*args,&blk)
          @origins = args.flatten.collect do |n|
            case n
            when Regexp, /^https?:\/\// then n
            when 'file://'              then n
            when '*'                    then @public_resources = true; n
            else                        ["http://#{n}", "https://#{n}"]
            end
          end.flatten
          @origins.push(blk) if blk
        end

        def resource(path, opts={})
          @resources << Resource.new(public_resources?, path, opts)
        end

        def public_resources?
          @public_resources
        end

        def allow_origin?(source,env = {})
          return true if public_resources?
          return !! @origins.detect do |origin|
            if origin.is_a?(Proc)
              origin.call(source,env)
            else
              origin === source
            end
          end
        end

        def find_resource(path)
          @resources.detect{|r| r.match?(path)}
        end
      end

      class Resource
        attr_accessor :path, :methods, :headers, :expose, :max_age, :credentials, :pattern

        def initialize(public_resource, path, opts={})
          self.path        = path
          self.methods     = prepare_and_validate_methods_option(opts[:methods]) || [:get]
          self.credentials = opts[:credentials].nil? ? true : opts[:credentials]
          self.max_age     = opts[:max_age] || 1728000
          self.pattern     = compile(path)
          @public_resource = public_resource

          self.headers = case opts[:headers]
          when :any then :any
          when nil then nil
          else
            [opts[:headers]].flatten.collect{|h| h.downcase}
          end

          self.expose = opts[:expose] ? [opts[:expose]].flatten : nil
        end

        def match?(path)
          pattern =~ path
        end

        def process_preflight(env)
          return nil if invalid_method_request?(env) || invalid_headers_request?(env)
          {'Content-Type' => 'text/plain'}.merge(to_preflight_headers(env))
        end

        def to_headers(env)
          x_origin = env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
          h = {
            'Access-Control-Allow-Origin'     => origin_for_response_header(env['HTTP_ORIGIN']),
            'Access-Control-Allow-Methods'    => methods.collect{|m| m.to_s.upcase}.join(', '),
            'Access-Control-Expose-Headers'   => expose.nil? ? '' : expose.join(', '),
            'Access-Control-Max-Age'          => max_age.to_s }
          h['Access-Control-Allow-Credentials'] = 'true' if credentials
          h
        end

        protected
          def public_resource?
            @public_resource
          end

          def origin_for_response_header(origin)
            return '*' if public_resource? && !credentials
            origin == 'file://' ? 'null' : origin
          end

          def to_preflight_headers(env)
            h = to_headers(env)
            if env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
              h.merge!('Access-Control-Allow-Headers' => env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS'])
            end
            h
          end

          def invalid_method_request?(env)
            request_method = env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']
            request_method.nil? || !methods.include?(request_method.downcase.to_sym)
          end

          def invalid_headers_request?(env)
            request_headers = env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']
            request_headers && !allow_headers?(request_headers)
          end

          def allow_headers?(request_headers)
            return false if headers.nil?
            headers == :any || begin
              request_headers = request_headers.split(/,\s*/) if request_headers.kind_of?(String)
              request_headers.all?{|h| headers.include?(h.downcase)}
            end
          end

          def prepare_and_validate_methods_option setting
            raise ArgumentError.new("rack-cors methods must be an single HTTP verb, or an array of verbs") if setting && setting == :any
            ensure_enum setting
          end

          def ensure_enum(v)
            return nil if v.nil?
            [v].flatten
          end

          def compile(path)
            if path.respond_to? :to_str
              special_chars = %w{. + ( )}
              pattern =
                path.to_str.gsub(/((:\w+)|[\*#{special_chars.join}])/) do |match|
                  case match
                  when "*"
                    "(.*?)"
                  when *special_chars
                    Regexp.escape(match)
                  else
                    "([^/?&#]+)"
                  end
                end
              /^#{pattern}$/
            elsif path.respond_to? :match
              path
            else
              raise TypeError, path
            end
          end
      end

  end
end
