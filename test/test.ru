require 'rack/cors'

use Rack::Cors do |cfg|
  cfg.allow do |allow|
    allow.origins 'localhost:3000', '127.0.0.1:3000', /http:\/\/192\.168\.0\.\d{1,3}(:\d+)?/

    allow.resource '/get-only', :methods => :get
    allow.resource '/', :headers => :any
    allow.resource '/single_header', :headers => 'x-domain-token'
    allow.resource '/two_headers', :headers => %w{x-domain-token x-requested-with}
    allow.resource '/expose_single_header', :expose => 'expose-test'
    allow.resource '/expose_multiple_headers', :expose => %w{expose-test-1 expose-test-2}
    # allow.resource '/file/at/*',
    #     :methods => [:get, :post, :put, :delete],
    #     :headers => :any,
    #     :max_age => 0
  end

  cfg.allow do |allow|
    allow.origins '*'
    allow.resource '/public'
  end
end

map '/' do
  run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
end