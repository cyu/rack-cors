require 'rubygems'
require 'rack/cors'
require 'shoulda'


class DSLTest < Test::Unit::TestCase
  should 'support explicit config object dsl mode' do
    cors = Rack::Cors.new(Proc.new {}) do |cfg|
      cfg.allow do |allow|
        allow.origins 'localhost:3000', '127.0.0.1:3000' do |source,env|
          source == "http://10.10.10.10:3000" &&
          env["USER_AGENT"] == "test-agent"
        end
        allow.resource '/get-only', :methods => :get
        allow.resource '/', :headers => :any
      end
    end
    resources = cors.send :all_resources
    assert_equal 1, resources.length
    assert resources.first.allow_origin?('http://localhost:3000')

    assert  resources.first.allow_origin?('http://10.10.10.10:3000',{"USER_AGENT" => "test-agent" })
    assert !resources.first.allow_origin?('http://10.10.10.10:3001',{"USER_AGENT" => "test-agent" })
    assert !resources.first.allow_origin?('http://10.10.10.10:3000',{"USER_AGENT" => "other-agent"})
  end

  should 'support implicit config object dsl mode' do
    cors = Rack::Cors.new(Proc.new {}) do
      allow do
        origins 'localhost:3000', '127.0.0.1:3000' do |source,env|
          source == "http://10.10.10.10:3000" &&
          env["USER_AGENT"] == "test-agent"
        end
        resource '/get-only', :methods => :get
        resource '/', :headers => :any
      end
    end
    resources = cors.send :all_resources
    assert_equal 1, resources.length
    assert resources.first.allow_origin?('http://localhost:3000')

    assert  resources.first.allow_origin?('http://10.10.10.10:3000',{"USER_AGENT" => "test-agent" })
    assert !resources.first.allow_origin?('http://10.10.10.10:3001',{"USER_AGENT" => "test-agent" })
    assert !resources.first.allow_origin?('http://10.10.10.10:3000',{"USER_AGENT" => "other-agent"})
  end
end
