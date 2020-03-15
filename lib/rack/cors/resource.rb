module Rack
  class Cors
    class Resource

      # All CORS routes need to accept CORS simple headers at all times
      # {https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Headers}
      CORS_SIMPLE_HEADERS = ['accept', 'accept-language', 'content-language', 'content-type'].freeze

      attr_accessor :path, :methods, :headers, :expose, :max_age, :credentials, :pattern, :if_proc, :vary_headers

      def initialize(public_resource, path, opts={})
        raise CorsMisconfigurationError if public_resource && opts[:credentials] == true

        self.path         = path
        self.credentials  = public_resource ? false : (opts[:credentials] == true)
        self.max_age      = opts[:max_age] || 7200
        self.pattern      = compile(path)
        self.if_proc      = opts[:if]
        self.vary_headers = opts[:vary] && [opts[:vary]].flatten
        @public_resource  = public_resource

        self.headers = case opts[:headers]
        when :any then :any
        when nil then nil
        else
          [opts[:headers]].flatten.collect{|h| h.downcase}
        end

        self.methods = case opts[:methods]
        when :any then [:get, :head, :post, :put, :patch, :delete, :options]
        else
          ensure_enum(opts[:methods]) || [:get]
        end.map{|e| e.to_s }

        self.expose = opts[:expose] ? [opts[:expose]].flatten : nil
      end

      def matches_path?(path)
        pattern =~ path
      end

      def match?(path, env)
        matches_path?(path) && (if_proc.nil? || if_proc.call(env))
      end

      def process_preflight(env, result)
        headers = {}

        request_method = env[Rack::Cors::HTTP_ACCESS_CONTROL_REQUEST_METHOD]
        if request_method.nil?
          result.miss(Result::MISS_NO_METHOD) and return headers
        end
        if !methods.include?(request_method.downcase)
          result.miss(Result::MISS_DENY_METHOD) and return headers
        end

        request_headers = env[Rack::Cors::HTTP_ACCESS_CONTROL_REQUEST_HEADERS]
        if request_headers && !allow_headers?(request_headers)
          result.miss(Result::MISS_DENY_HEADER) and return headers
        end

        result.hit = true
        headers.merge(to_preflight_headers(env))
      end

      def to_headers(env)
        h = {
          'Access-Control-Allow-Origin'     => origin_for_response_header(env[Rack::Cors::HTTP_ORIGIN]),
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
        return '*' if public_resource?
        origin
      end

      def to_preflight_headers(env)
        h = to_headers(env)
        if env[Rack::Cors::HTTP_ACCESS_CONTROL_REQUEST_HEADERS]
          h.merge!('Access-Control-Allow-Headers' => env[Rack::Cors::HTTP_ACCESS_CONTROL_REQUEST_HEADERS])
        end
        h
      end

      def allow_headers?(request_headers)
        headers = self.headers || []
        if headers == :any
          return true
        end
        request_headers = request_headers.split(/,\s*/) if request_headers.kind_of?(String)
        request_headers.all? do |header|
          header = header.downcase
          CORS_SIMPLE_HEADERS.include?(header) || headers.include?(header)
        end
      end

      def ensure_enum(v)
        return nil if v.nil?
        [v].flatten
      end

      def compile(path)
        if path.respond_to? :to_str
          special_chars = %w{. + ( )}
          pattern =
            path.to_str.gsub(/((:\w+)|\/\*|[\*#{special_chars.join}])/) do |match|
              case match
              when "/*"
                "\\/?(.*?)"
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
