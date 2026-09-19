class ApplicationController < ActionController::API
  before_action :set_cors_headers

  def options
    head :no_content
  end

  private

  def set_cors_headers
    allowed_origin = ENV["DASHBOARD_ORIGIN"].presence || ("*" unless Rails.env.production?)
    return if allowed_origin.blank?

    response.headers["Access-Control-Allow-Origin"] = allowed_origin
    response.headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type, X-Business-Slug"
    response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, PUT, DELETE, OPTIONS"
  end

  def requested_business
    @requested_business ||= Business.find_by(slug: request.headers["X-Business-Slug"]) || Business.default
  end
end
