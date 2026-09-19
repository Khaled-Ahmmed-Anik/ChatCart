module Api
  class DeliveryIntegrationsController < BaseController
    before_action -> { require_roles!(:owner, :admin) }

    def show
      return if performed?

      integration = current_business.delivery_integration
      render json: integration ? serialize(integration) : {}
    end

    def update
      return if performed?

      integration = current_business.delivery_integration || current_business.build_delivery_integration
      integration.update!(integration_params)
      render json: serialize(integration)
    end

    private

    def integration_params
      params.expect(delivery_integration: [ :provider, :endpoint_url, :api_key, :active, settings: {} ])
    end

    def serialize(integration)
      integration.as_json(except: :api_key).merge(configured: integration.api_key.present?)
    end
  end
end
