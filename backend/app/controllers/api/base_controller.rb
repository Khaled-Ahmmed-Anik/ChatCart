module Api
  class BaseController < ApplicationController
    before_action :authenticate_user!

    private

    attr_reader :current_user

    def current_business
      current_user.business
    end

    def authenticate_user!
      token = request.authorization.to_s.delete_prefix("Bearer ")
      session = AuthSession.authenticate(token)
      @current_user = session&.user || User.authenticate_token(token)
      return if current_user

      render json: { error: "Unauthorized" }, status: :unauthorized
    end

    def require_roles!(*roles)
      return if current_user.role.in?(roles.map(&:to_s))

      render json: { error: "Forbidden" }, status: :forbidden
    end
  end
end
