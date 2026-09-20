module Api
  class AnalyticsController < BaseController
    def show
      render json: AnalyticsSnapshot.new(business: current_business).call
    end
  end
end
