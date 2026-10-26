class ApplicationController < ActionController::API
  before_action :authenticate_user!
  attr_reader :current_user

  private

  def authenticate_user!
    raw_token = request.headers["Authorization"].to_s.match(/\ABearer\s+(.+)\z/i)&.captures&.first
    @current_user = User.from_api_token(raw_token)
    return if @current_user

    render json: { error: { code: "UNAUTHORIZED", message: "A valid bearer token is required." } }, status: :unauthorized
  end

  def authorize_roles!(*roles)
    return if current_user && roles.include?(current_user.role)

    render json: { error: { code: "FORBIDDEN", message: "You do not have permission to perform this action." } }, status: :forbidden
  end
end
