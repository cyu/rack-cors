Rails.application.routes.draw do
  resources :cors
  match '/', :to => proc {|env| [200, {'Content-Type' => 'text/plain'}, ["Hello world"]] },
             :via => [:get, :post, :put, :delete, :options, :head, :patch]
end
