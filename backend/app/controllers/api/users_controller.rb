module Api
  class UsersController < BaseController
    before_action -> { require_roles!(:owner, :admin) }
    before_action :set_user, only: %i[update destroy]

    def index
      return if performed?

      render json: current_business.users.as_json(except: :api_token_digest)
    end

    def create
      return if performed?

      token, digest = User.issue_token
      user = current_business.users.create!(user_params.merge(api_token_digest: digest))
      render json: user.as_json(except: :api_token_digest).merge(api_token: token), status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    def update
      return if performed?

      @user.update!(user_params)
      render json: @user.as_json(except: :api_token_digest)
    end

    def destroy
      return if performed?

      @user.update!(active: false)
      head :no_content
    end

    private

    def set_user
      @user = current_business.users.find(params[:id])
    end

    def user_params
      params.expect(user: %i[name email password role active])
    end
  end
end
