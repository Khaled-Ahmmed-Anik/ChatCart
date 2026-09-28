module Api
  class BusinessPoliciesController < BaseController
    before_action -> { require_roles!(:owner, :admin) }, only: :update

    def show
      render json: current_business.policy
    end

    def update
      return if performed?

      policy = current_business.business_policy || current_business.build_business_policy
      policy.update!(policy_params)
      render json: policy
    end

    private

    def policy_params
      params.expect(business_policy: %i[
        payment_methods cash_on_delivery delivery_charges delivery_areas delivery_time
        return_policy additional_information authenticity_statement discount_policy trial_policy
        trust_information bulk_order_policy
      ])
    end
  end
end
