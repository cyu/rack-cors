require 'logger'
require_relative "cors/resources"
require_relative "cors/resource"
require_relative "cors/result"
require_relative "cors/version"

module Rack
  class Cors
    HTTP_ORIGIN   = 'HTTP_ORIGIN'.freeze
    HTTP_X_ORIGIN = 'HTTP_X_ORIGIN'.freeze

    HTTP_ACCESS_CONTROL_REQUEST_METHOD  = 'HTTP_ACCESS_CONTROL_REQUEST_METHOD'.freeze
    HTTP_ACCESS_CONTROL_REQUEST_HEADERS = 'HTTP_ACCESS_CONTROL_REQUEST_HEADERS'.freeze

    PATH_INFO      = 'PATH_INFO'.freeze
    REQUEST_METHOD = 'REQUEST_METHOD'.freeze

    RACK_LOGGER = 'rack.logger'.freeze
    RACK_CORS   =
    # retaining the old key for backwards compatibility
    ENV_KEY     = 'rack.cors'.freeze

    OPTIONS     = 'OPTIONS'.freeze
    VARY        = 'Vary'.freeze

    DEFAULT_VARY_HEADERS = ['Origin'].freeze

    # All CORS routes need to accept CORS simple headers at all times
    # {https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Access-Control-Allow-Headers}
    CORS_SIMPLE_HEADERS = ['accept', 'accept-language', 'content-language', 'content-type'].freeze

    def initialize(app, opts={}, &block)
      @app = app
      @debug_mode = !!opts[:debug]
      @logger = @logger_proc = nil

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
      env[HTTP_ORIGIN] ||= env[HTTP_X_ORIGIN] if env[HTTP_X_ORIGIN]

      path = evaluate_path(env)

      add_headers = nil
      if env[HTTP_ORIGIN]
        debug(env) do
          [ 'Incoming Headers:',
            "  Origin: #{env[HTTP_ORIGIN]}",
            "  Path-Info: #{path}",
            "  Access-Control-Request-Method: #{env[HTTP_ACCESS_CONTROL_REQUEST_METHOD]}",
            "  Access-Control-Request-Headers: #{env[HTTP_ACCESS_CONTROL_REQUEST_HEADERS]}"
            ].join("\n")
        end

        if env[REQUEST_METHOD] == OPTIONS && env[HTTP_ACCESS_CONTROL_REQUEST_METHOD]
          return [400, {}, []] unless Rack::Utils.valid_path?(path)
          headers = process_preflight(env, path)
          debug(env) do
            "Preflight Headers:\n" +
                headers.collect{|kv| "  #{kv.join(': ')}"}.join("\n")
          end
          return [200, headers, []]
        else
          add_headers = process_cors(env, path)
        end
      else
        Result.miss(env, Result::MISS_NO_ORIGIN)
      end

      # This call must be done BEFORE calling the app because for some reason
      # env[PATH_INFO] gets changed after that and it won't match. (At least
      # in rails 4.1.6)
      vary_resource = resource_for_path(path)

      status, headers, body = @app.call env

      if add_headers
        headers = add_headers.merge(headers)
        debug(env) do
          add_headers.each_pair do |key, value|
            if headers.has_key?(key)
              headers["X-Rack-CORS-Original-#{key}"] = value
            end
          end
        end
      end

      # Vary header should ALWAYS mention Origin if there's ANY chance for the
      # response to be different depending on the Origin header value.
      # Better explained here: http://www.fastly.com/blog/best-practices-for-using-the-vary-header/
      if vary_resource
        vary = headers[VARY]
        cors_vary_headers = if vary_resource.vary_headers && vary_resource.vary_headers.any?
          vary_resource.vary_headers
        else
          DEFAULT_VARY_HEADERS
        end
        headers[VARY] = ((vary ? ([vary].flatten.map { |v| v.split(/,\s*/) }.flatten) : []) + cors_vary_headers).uniq.join(', ')
      end

      if debug? && result = env[ENV_KEY]
        result.append_header(headers)
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

      elsif defined?(Rails) && Rails.respond_to?(:logger) && Rails.logger
        Rails.logger

      elsif env[RACK_LOGGER]
        env[RACK_LOGGER]

      else
        ::Logger.new(STDOUT).tap { |logger| logger.level = ::Logger::Severity::DEBUG }
      end
    end

    def evaluate_path(env)
      path = env[PATH_INFO]

      if path
        path = Rack::Utils.unescape_path(path)

        if Rack::Utils.valid_path?(path)
          path = Rack::Utils.clean_path_info(path)
        end
      end

      path
    end

    def all_resources
      @all_resources ||= []
    end

    def process_preflight(env, path)
      result = Result.preflight(env)

      resource, error = match_resource(path, env)
      unless resource
        result.miss(error)
        return {}
      end

      return resource.process_preflight(env, result)
    end

    def process_cors(env, path)
      resource, error = match_resource(path, env)
      if resource
        Result.hit(env)
        cors = resource.to_headers(env)
        cors

      else
        Result.miss(env, error)
        nil
      end
    end

    def resource_for_path(path_info)
      all_resources.each do |r|
        if found = r.resource_for_path(path_info)
          return found
        end
      end
      nil
    end

    def match_resource(path, env)
      origin = env[HTTP_ORIGIN]

      origin_matched = false
      all_resources.each do |r|
        if r.allow_origin?(origin, env)
          origin_matched = true
          if found = r.match_resource(path, env)
            return [found, nil]
          end
        end
      end

      [nil, origin_matched ? Result::MISS_NO_PATH : Result::MISS_NO_ORIGIN]
    end
  end
end
