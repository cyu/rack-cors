class WelcomeController < ApplicationController
  skip_before_action :verify_authenticity_token
  def index
    render plain: "Hello world"
  end
end
