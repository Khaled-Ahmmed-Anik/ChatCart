module Auth
  class AdminSessionsController < ApplicationController
    def create
      administrator = PlatformAdministrator.find_by(email: normalized_email)&.authenticate(params[:password])
      return render json: { error: "Invalid email or password" }, status: :unauthorized unless administrator

      token, session = AuthSession.issue!(
        actor: administrator, ip_address: request.remote_ip, user_agent: request.user_agent
      )
      administrator.update!(last_seen_at: Time.current)
      render json: {
        token: token,
        expires_at: session.expires_at.iso8601,
        actor_type: "platform_administrator",
        administrator: administrator.as_json(only: %i[id name email])
      }
    end

    private

    def normalized_email
      params[:email].to_s.strip.downcase
    end
  end
end
