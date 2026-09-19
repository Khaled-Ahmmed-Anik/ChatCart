module Api
  class ChannelConnectionsController < BaseController
    before_action -> { require_roles!(:owner, :admin) }
    before_action :set_connection, only: %i[update destroy]

    def index
      return if performed?

      render json: current_business.channel_connections.map { |connection| serialize(connection) }
    end

    def create
      return if performed?

      connection = current_business.channel_connections.create!(connection_params)
      render json: serialize(connection), status: :created
    end

    def update
      return if performed?

      @connection.update!(connection_params)
      render json: serialize(@connection)
    end

    def destroy
      return if performed?

      @connection.update!(status: "disconnected", access_token: nil)
      head :no_content
    end

    private

    def set_connection
      @connection = current_business.channel_connections.find(params[:id])
    end

    def connection_params
      params.expect(channel_connection: [ :channel, :external_account_id, :display_name, :access_token, :verify_token, :status, settings: {} ])
    end

    def serialize(connection)
      connection.as_json(except: %i[access_token verify_token]).merge(configured: connection.access_token.present?)
    end
  end
end
