require 'logger'

module Rack
  class Cors
    def initialize(app, opts={})
      @app = app
      @logger = opts[:logger]
      yield self if block_given?
    end

    def allow
      all_resources << (resources = Resources.new)
      yield resources
    end

    def call(env)
      cors_headers = nil
      if env['HTTP_ORIGIN']
        debug(env) do
          [ 'Incoming Headers:',
            "  Origin: #{env['HTTP_ORIGIN']}",
            "  Access-Control-Request-Method: #{env['HTTP_ACCESS_CONTROL_REQUEST_METHOD']}",
            "  Access-Control-Request-Headers: #{env['HTTP_ACCESS_CONTROL_REQUEST_HEADERS']}"
            ].join("\n")
        end
        if env['REQUEST_METHOD'] == 'OPTIONS'
          headers = process_preflight(env)
          debug(env) do
            "Preflight Headers:\n" +
                headers.collect{|kv| "  #{kv.join(': ')}"}.join("\n")
          end
          return [200, headers, []] if headers
        end
        cors_headers = process_cors(env)
      end
      status, headers, body = @app.call env
      headers = headers.merge(cors_headers) if cors_headers
      [status, headers, body]
    end

    protected
      def debug(env, message = nil, &block)
        logger = @logger || env['rack.logger'] || begin
          @logger = ::Logger.new(STDOUT).tap {|logger| logger.level = ::Logger::Severity::DEBUG}
        end
        logger.debug(message, &block)
      end

      def all_resources
        @all_resources ||= []
      end

      def process_preflight(env)
        resource = find_resource(env['HTTP_ORIGIN'], env['PATH_INFO'])
        resource.to_preflight_headers(env) if resource
      end

      def process_cors(env)
        resource = find_resource(env['HTTP_ORIGIN'], env['PATH_INFO'])
        resource.to_headers(env) if resource
      end

      def find_resource(origin, path)
        allowed = all_resources.detect {|r| r.allow_origin?(origin)}
        allowed ? allowed.find_resource(path) : nil
      end

      class Resources
        def initialize
          @origins   = []
          @resources = []
        end

        def origins(*args)
          @origins = args.flatten.collect{|n| "http://#{n}" unless n.match(/^https?:\/\//)}
        end

        def resource(path, opts={})
          @resources << Resource.new(path, opts)
        end

        def allow_origin?(source)
          @origins.include?(source)
        end

        def find_resource(path)
          @resources.detect{|r| r.match?(path)}
        end
      end

      class Resource
        attr_accessor :path, :methods, :headers, :max_age, :credentials, :pattern

        def initialize(path, opts = {})
          self.path        = path
          self.methods     = ensure_enum(opts[:methods]) || [:get]
          self.credentials = opts[:credentials] || true
          self.headers     = ensure_enum(opts[:headers]) || nil
          self.max_age     = opts[:max_age] || 1728000
          self.pattern     = compile(path)
        end

        def match?(path)
          pattern =~ path
        end

        def to_headers(env)
          { 'Access-Control-Allow-Origin'       => env['HTTP_ORIGIN'],
            'Access-Control-Allow-Methods'      => methods.collect{|m| m.to_s.upcase}.join(', '),
            'Access-Control-Allow-Credentials'  => credentials.to_s,
            'Access-Control-Max-Age'            => max_age.to_s }
        end

        def to_preflight_headers(env)
          h = to_headers(env)
          h.merge!('Access-Control-Allow-Headers' => headers.join(', ')) if headers
          h
        end

        protected
          def ensure_enum(v)
            return nil if v.nil?
            [v] unless v.respond_to?(:join)
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
