class Api::V1::UsersController < ApplicationController
  before_action -> { authorize_roles!("admin") }

  def index
    render json: { data: User.order(:email).select(:id, :email, :role, :active, :created_at) }
  end

  def create
    user = User.new(user_params)
    if user.save
      render json: { data: user.as_json(only: %i[id email role active created_at]) }, status: :created
    else
      render json: { error: { code: "VALIDATION_FAILED", message: "The user could not be created.", details: user.errors.to_hash } }, status: :unprocessable_entity
    end
  end

  def update
    user = User.find(params[:id])
    if user == current_user && params.dig(:user, :active) == false
      return render json: { error: { code: "INVALID_OPERATION", message: "You cannot deactivate your own account." } }, status: :unprocessable_entity
    end
    if user.update(user_params)
      render json: { data: user.as_json(only: %i[id email role active created_at]) }
    else
      render json: { error: { code: "VALIDATION_FAILED", message: "The user could not be updated.", details: user.errors.to_hash } }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: { code: "NOT_FOUND", message: "User not found." } }, status: :not_found
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :role, :active)
  end
end
