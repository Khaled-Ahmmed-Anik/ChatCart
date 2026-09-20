class GraphqlController < ApplicationController
  before_action :authenticate_user!

  def execute
    return if performed?

    result = ChatcartSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      context: { current_user: current_user, current_business: current_user.business },
      operation_name: params[:operationName]
    )
    render json: result
  rescue StandardError => error
    raise error unless Rails.env.development?

    handle_error_in_development(error)
  end

  private

  attr_reader :current_user

  def authenticate_user!
    token = request.authorization.to_s.delete_prefix("Bearer ")
    session = AuthSession.authenticate(token)
    @current_user = session&.user || User.authenticate_token(token)
    return if current_user

    render json: { errors: [ { message: "Unauthorized" } ] }, status: :unauthorized
  end

  def prepare_variables(variables_param)
    case variables_param
    when String
      variables_param.present? ? JSON.parse(variables_param) : {}
    when Hash, ActionController::Parameters
      variables_param.to_unsafe_hash
    when nil
      {}
    else
      raise ArgumentError, "Unexpected variables parameter"
    end
  end

  def handle_error_in_development(error)
    logger.error error.message
    logger.error error.backtrace.join("\n")
    render json: { errors: [ { message: error.message, backtrace: error.backtrace } ] }, status: :internal_server_error
  end
end
