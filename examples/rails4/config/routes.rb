Rails.application.routes.draw do
  resources :cors
  root :to => proc {|env| [200, {'Content-Type' => 'text/plain'}, ["Hello world"]] }
end
