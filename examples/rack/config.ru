require 'rack/cors'

app = Rack::Builder.app do
  use Rack::Cors, :debug => true, :logger => Logger.new(STDOUT) do
    allow do
      origins '*'

      resource '/cors',
        :headers => :any,
        :methods => [:post],
        :max_age => 0

      resource '*',
        :headers => :any,
        :methods => [:get, :post, :delete, :put, :patch, :options, :head],
        :max_age => 0
    end
  end

  use Rack::Static, :urls => ["/static.txt"], :root => 'public'

  map "/cors" do
    run lambda { |env|
      [
        200,
        {'Content-Type' => 'text/plain'},
        env[Rack::REQUEST_METHOD] == "HEAD" ? [] : ['OK!']
      ]
    }
  end

  run lambda { |env|
    [
      200,
      {'Content-Type' => 'text/plain'},
      env[Rack::REQUEST_METHOD] == "HEAD" ? [] : ["Hello world"]
    ]
  }
end

run app
