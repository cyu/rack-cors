module Rack
  class Cors

    def initialize(app)
      @app = app
      yield self if block_given?
    end

    def allow(origin, path, opts={})
      origins << Origin.new(origin, path, opts)
    end

    def call(env)
      cors_headers = nil
      if env['HTTP_ORIGIN']
        if env['REQUEST_METHOD'] == 'OPTIONS'
          headers = process_preflight(env) 
          return [200, headers, []] if headers
        end
        cors_headers = process_cors(env)
      end
      status, headers, body = @app.call env
      headers = headers.merge(cors_headers) if cors_headers
      [status, headers, body]
    end

    def origins
      @origins ||= []
    end

    class Origin
      attr_accessor :names, :path, :allow_methods, :allow_headers, :max_age, :allow_credentials

      def initialize(names, path, opts={})
        self.names = [names].flatten.collect{|n| "http://#{n}" unless n.match(/^https?:\/\//)}
        self.path  = path

        self.allow_methods     = ensure_enum(opts[:allow_methods]) || [:get]
        self.allow_credentials = opts[:allow_credentials] || true
        self.max_age           = opts[:max_age] || 1728000
        self.allow_headers     = ensure_enum(opts[:allow_headers]) || nil
      end

      def match?(source)
        names.include?(source)
      end

      def to_headers(env)
        { 'Access-Control-Allow-Origin'       => env['HTTP_ORIGIN'],
          'Access-Control-Allow-Methods'      => allow_methods_header,
          'Access-Control-Allow-Credentials'  => allow_credentials.to_s,
          'Access-Control-Max-Age'            => max_age.to_s }
      end

      def to_preflight_headers(env)
        h = to_headers(env)
        h.merge!('Access-Control-Allow-Headers' => allow_headers.join(', ')) if allow_headers
        h
      end

      protected
        def allow_methods_header
          allow_methods.collect{|m| m.to_s.upcase}.join(', ')
        end

        def ensure_enum(v)
          return nil if v.nil?
          [v] unless v.respond_to?(:join)
        end
    end

    protected
      def process_preflight(env)
        origin = find_origin(env['HTTP_ORIGIN'])
        origin.to_preflight_headers(env) if origin
      end

      def process_cors(env)
        origin = find_origin(env['HTTP_ORIGIN'])
        origin.to_headers(env) if origin
      end

      def find_origin(source_origin)
        origins.detect {|origin| origin.match?(source_origin)}
      end
  end
end
