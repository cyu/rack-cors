require 'rack/cors'

use Rack::Cors do
  allow do
    origins 'localhost:3000', '127.0.0.1:3000', /http:\/\/192\.168\.0\.\d{1,3}(:\d+)?/

    resource '/get-only', :methods => :get
    resource '/', :headers => :any
    resource '/single_header', :headers => 'x-domain-token'
    resource '/two_headers', :headers => %w{x-domain-token x-requested-with}
    resource '/expose_single_header', :expose => 'expose-test'
    resource '/expose_multiple_headers', :expose => %w{expose-test-1 expose-test-2}
    # resource '/file/at/*',
    #     :methods => [:get, :post, :put, :delete],
    #     :headers => :any,
    #     :max_age => 0
  end

  allow do
    origins '*'
    resource '/public'
  end
end

map '/' do
  run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
end