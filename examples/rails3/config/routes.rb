Rails3::Application.routes.draw do
  resources :cors
  root :to => proc {|env| [200, {}, ["Hello world"]] }
end
