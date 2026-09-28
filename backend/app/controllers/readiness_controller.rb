class ReadinessController < ApplicationController
  def show
    result = DeploymentReadiness.new.call
    render json: result, status: result[:ready] ? :ok : :service_unavailable
  end
end
