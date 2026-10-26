class Api::V1::AuthController < ApplicationController
  skip_before_action :authenticate_user!, only: :login

  def login
    user = User.find_by(email: params[:email].to_s.strip.downcase)
    unless user&.authenticate(params[:password].to_s) && user.active?
      return render json: { error: { code: "INVALID_CREDENTIALS", message: "Email or password is incorrect." } }, status: :unauthorized
    end

    token = user.issue_api_token!
    render json: { data: { token: token, expires_at: user.token_expires_at, user: user_payload(user) } }
  end

  def logout
    current_user.revoke_api_token!
    head :no_content
  end

  def me
    render json: { data: user_payload(current_user) }
  end

  private

  def user_payload(user)
    { id: user.id, email: user.email, role: user.role }
  end
end
