module Api
  class BusinessesController < BaseController
    before_action -> { require_roles!(:owner, :admin) }, only: :update

    def show
      render json: serialize(current_business)
    end

    def update
      return if performed?

      current_business.update!(business_params)
      render json: serialize(current_business)
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def business_params
      params.expect(business: [ :name, :category, :default_language, :timezone, :currency, settings: {} ])
    end

    def serialize(business)
      business.as_json(only: %i[id name slug category default_language timezone currency status settings])
    end
  end
end
