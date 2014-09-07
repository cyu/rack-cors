# Rack CORS Middleware

`Rack::Cors` provides support for Cross-Origin Resource Sharing (CORS) for Rack compatible web applications.  The CORS spec allows web applications to make cross domain AJAX calls without
using workarounds such as JSONP.  For a thorough write up on CORS, see this blog post:

http://www.nczonline.net/blog/2010/05/25/cross-domain-ajax-with-cross-origin-resource-sharing/

Or for all the gory details, you can read the spec here:

http://www.w3.org/TR/cors/

## Installation

Install the gem:

`gem install rack-cors`

Or in your Gemfile:

```ruby
gem 'rack-cors', :require => 'rack/cors'
```


## Configuration

### Rack

You configure `Rack::Cors` by passing a block to the `use` command:

```ruby
use Rack::Cors do
  allow do
    origins 'localhost:3000', '127.0.0.1:3000',
            /http:\/\/192\.168\.0\.\d{1,3}(:\d+)?/
            # regular expressions can be used here

    resource '/file/list_all/', :headers => 'x-domain-token'
    resource '/file/at/*',
        :methods => [:get, :post, :put, :delete, :options],
        :headers => 'x-domain-token',
        :expose  => ['Some-Custom-Response-Header'],
        :max_age => 600
        # headers to expose
  end

  allow do
    origins '*'
    resource '/public/*', :headers => :any, :methods => :get
  end
end
```

### Rails
Put something like the code below in `config/application.rb` of your Rails application. For example, this will allow GET, POST or OPTIONS requests from any origin on any resource.

```ruby
module YourApp
  class Application < Rails::Application

    # ...

    config.middleware.insert_before "ActionDispatch::Static", "Rack::Cors" do
      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :post, :options]
      end
    end
      
  end
end
```
Refer to `examples/rails3` and `examples/rails4` for more details.

See http://guides.rubyonrails.org/rails_on_rack.html for more details on rack middlewares or
http://railscasts.com/episodes/151-rack-middleware.

#### Positioning in the Middleware Stack

A common issue with `Rack::Cors` is that incorrect positioning of `Rack::Cors` in the middleware stack can produce unexpected results.  Here are some common middleware that `Rack::Cors` should be inserted before:

* **ActionDispatch::Static** if you want to serve static files.  Note that this might still not work as static files are usually served from the web server (Nginx, Apache) and not the Rails container.
* **Rack::Cache** if your resources are going to be cached.
* **Warden::Manager** if your resources are going to require authentication

