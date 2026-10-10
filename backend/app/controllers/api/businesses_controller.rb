module Api
  class BusinessesController < BaseController
    before_action -> { require_roles!(:owner, :admin) }, only: :update

    def show
      render json: serialize(current_business)
    end

    def update
      return if performed?

      attributes = business_params
      if attributes.key?(:usd_exchange_rate)
        rate = attributes.delete(:usd_exchange_rate)
        attributes[:settings] = current_business.settings.to_h.merge("usd_exchange_rate" => rate.presence)
      end
      current_business.update!(attributes)
      render json: serialize(current_business)
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def business_params
      params.expect(business: [ :name, :category, :default_language, :timezone, :currency, :usd_exchange_rate, settings: {} ])
    end

    def serialize(business)
      business.as_json(only: %i[id name slug category default_language timezone currency status settings]).merge(
        "usd_exchange_rate" => business.settings.to_h["usd_exchange_rate"]
      )
    end
  end
end
