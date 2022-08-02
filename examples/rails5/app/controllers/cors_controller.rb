class CorsController < ApplicationController
  skip_before_action :verify_authenticity_token
  def create
    render plain: 'OK!'
  end
end
