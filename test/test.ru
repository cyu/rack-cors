require 'rack/cors'

use Rack::Cors do |cfg|
  cfg.allow do |allow|
    allow.origins 'localhost:3000', '127.0.0.1:3000'

    allow.resource '/get-only', :methods => :get
    allow.resource '/', :headers => :any
    allow.resource '/single_header', :headers => 'x-domain-token'
    # allow.resource '/file/at/*',
    #     :methods => [:get, :post, :put, :delete],
    #     :headers => :any,
    #     :max_age => 0
  end
end

map '/' do
  run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
end