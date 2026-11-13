module Api
  class BusinessesController < BaseController
    before_action -> { require_roles!(:owner, :admin) }, only: :update

    def show
      render json: serialize(current_business)
    end

    def update
      return if performed?

      attributes = business_params
      if attributes.key?(:automation_paused) && ![ true, false ].include?(attributes[:automation_paused])
        return render json: { error: I18n.t("automation.invalid_value") }, status: :unprocessable_entity
      end
      current_business.with_lock do
        pause_requested = attributes.key?(:automation_paused)
        paused = attributes.delete(:automation_paused)
        values = current_business.settings.to_h.merge(attributes.delete(:settings).to_h.except(
          Constants::Automation::PAUSED, Constants::Automation::PAUSED_AT, Constants::Automation::RESUMED_AT
        ))
        values["usd_exchange_rate"] = attributes.delete(:usd_exchange_rate).presence if attributes.key?(:usd_exchange_rate)
        current_business.assign_attributes(attributes.merge(settings: values))
        current_business.automation_paused = paused if pause_requested
        current_business.save!
      end
      render json: serialize(current_business)
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    private

    def business_params
      params.expect(business: [ :name, :category, :default_language, :timezone, :currency, :usd_exchange_rate, :automation_paused, settings: {} ])
    end

    def serialize(business)
      business.as_json(only: %i[id name slug category default_language timezone currency status settings]).merge(
        "usd_exchange_rate" => business.settings.to_h["usd_exchange_rate"],
        "automation_paused" => business.automation_paused?
      )
    end
  end
end
