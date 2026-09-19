module Admin
  class BusinessesController < BaseController
    def index
      render json: Business.order(:name).as_json(
        only: %i[id name slug category status default_language timezone currency created_at]
      )
    end

    def create
      token, digest = User.issue_token
      business = nil
      Business.transaction do
        business = Business.create!(business_params)
        business.create_business_policy!
        business.create_delivery_integration!
        business.users.create!(owner_params.merge(role: "owner", api_token_digest: digest))
      end
      render json: {
        business: business.as_json(only: %i[id name slug category status]),
        owner_api_token: token
      }, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    def update
      business = Business.find(params[:id])
      business.update!(params.expect(business: [ :status ]))
      render json: business
    end

    private

    def business_params
      params.expect(business: %i[name slug category default_language timezone currency])
    end

    def owner_params
      params.expect(owner: %i[name email password])
    end
  end
end
