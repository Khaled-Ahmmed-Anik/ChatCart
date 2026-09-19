module Api
  class ProductsController < BaseController
    before_action -> { require_roles!(:owner, :admin) }, except: %i[index show]
    before_action :set_product, only: %i[show update destroy]

    def index
      render json: current_business.products.order(:name)
    end

    def show
      render json: @product
    end

    def create
      return if performed?

      product = current_business.products.create!(product_params)
      render json: product, status: :created
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    def update
      return if performed?

      @product.update!(product_params)
      render json: @product
    rescue ActiveRecord::RecordInvalid => error
      render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
    end

    def destroy
      return if performed?

      @product.update!(active: false)
      head :no_content
    end

    private

    def set_product
      @product = current_business.products.find(params[:id])
    end

    def product_params
      params.expect(product: [ :name, :woo_commerce_product_id, :price, :stock_quantity, :description, :tags, :active ])
    end
  end
end
