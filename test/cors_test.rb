require 'rubygems'
require 'rack/test'
require 'shoulda'

Rack::Test::Session.class_eval do
  def options(uri, params = {}, env = {}, &block)
    env = env_for(uri, env.merge(:method => "OPTIONS", :params => params))
    process_request(uri, env, &block)
  end  
end

Rack::Test::Methods.class_eval do
  def_delegator :current_session, :options
end

class CorsTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    eval "Rack::Builder.new {( " + File.read(File.dirname(__FILE__) + '/test.ru') + "\n )}"
  end

  context 'preflight requests' do
    should 'fail if origin is invalid' do
      preflight_request('http://allyourdataarebelongtous.com', '/')
      assert_preflight_failure
    end

    should 'fail if Access-Control-Request-Method does not exist' do
      preflight_request('http://localhost:3000', '/', :method => nil)
      assert_preflight_failure
    end

    should 'fail if Access-Control-Request-Method is not allowed' do
      preflight_request('http://localhost:3000', '/get-only', :method => :post)
      assert_preflight_failure
    end

    should 'fail if header is not allowed' do
      preflight_request('http://localhost:3000', '/single_header', :headers => 'Fooey')
      assert_preflight_failure
    end

    should 'allow any header if headers = :any' do
      preflight_request('http://localhost:3000', '/', :headers => 'Fooey')
      assert_preflight_success
    end

    should 'allow header case insensitive match' do
      preflight_request('http://localhost:3000', '/single_header', :headers => 'X-Domain-Token')
      assert_preflight_success
    end
  end

  protected
    def preflight_request(origin, path, opts = {})
      header 'Origin', origin
      unless opts.key?(:method) && opts[:method].nil?
        header 'Access-Control-Request-Method', opts[:method] ? opts[:method].to_s.upcase : 'GET'
      end
      if opts[:headers]
        header 'Access-Control-Request-Headers', [opts[:headers]].flatten.join(', ')
      end
      options path
    end

    def assert_preflight_success
      assert_not_nil last_response.headers['Access-Control-Allow-Origin']
    end

    def assert_preflight_failure
      assert_nil last_response.headers['Access-Control-Allow-Origin']
    end
end