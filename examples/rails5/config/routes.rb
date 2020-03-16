# frozen_string_literal: true

Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :cors
  match '/', to: 'welcome#index', via: %i[get post put delete options head patch]
  match '/*glob', to: 'welcome#index', via: %i[get post put delete options head patch]
end
