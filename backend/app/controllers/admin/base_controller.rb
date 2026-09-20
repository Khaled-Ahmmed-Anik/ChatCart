module Admin
  class BaseController < ApplicationController
    before_action :authenticate_platform_admin!

    private

    def authenticate_platform_admin!
      configured_token = ENV["PLATFORM_ADMIN_TOKEN"]
      supplied_token = request.authorization.to_s.delete_prefix("Bearer ")
      session = AuthSession.authenticate(supplied_token)
      return if session&.platform_administrator
      return if configured_token.present? && supplied_token.bytesize == configured_token.bytesize &&
        ActiveSupport::SecurityUtils.secure_compare(supplied_token, configured_token)

      render json: { error: "Unauthorized" }, status: :unauthorized
    end
  end
end
