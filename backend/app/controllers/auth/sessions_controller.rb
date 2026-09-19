module Auth
  class SessionsController < ApplicationController
    def create
      user = User.find_by(email: normalized_email)&.authenticate(params[:password])
      return render_invalid_credentials unless user

      token, session = AuthSession.issue!(actor: user, ip_address: request.remote_ip, user_agent: request.user_agent)
      user.update!(last_seen_at: Time.current)
      render json: {
        token: token,
        expires_at: session.expires_at.iso8601,
        actor_type: "business_user",
        user: user.as_json(only: %i[id name email role]),
        business: user.business.as_json(only: %i[id name slug category])
      }
    end

    def destroy
      AuthSession.authenticate(bearer_token)&.destroy!
      head :no_content
    end

    private

    def normalized_email
      params[:email].to_s.strip.downcase
    end

    def bearer_token
      request.authorization.to_s.delete_prefix("Bearer ")
    end

    def render_invalid_credentials
      render json: { error: "Invalid email or password" }, status: :unauthorized
    end
  end
end
