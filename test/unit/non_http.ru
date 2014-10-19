require 'rack/cors'

use Rack::Cors do
  allow do
    origins 'com.company.app'
    resource '/public'
  end
end

map '/' do
  run Proc.new { |env| [200, {'Content-Type' => 'text/html'}, ['success']] }
end
