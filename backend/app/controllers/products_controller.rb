class ProductsController < ApplicationController
  def index
    products = Product.active.in_stock.order(:name)

    render json: products.map { |product| serialize_product(product) }
  end

  def create
    product = Product.create!(product_params)

    render json: serialize_product(product), status: :created
  rescue ActiveRecord::RecordInvalid => error
    render json: { errors: error.record.errors.to_hash(true) }, status: :unprocessable_entity
  end

  private

  def product_params
    params.expect(
      product: [
        :name,
        :woo_commerce_product_id,
        :price,
        :stock_quantity,
        :description,
        :tags,
        :active
      ]
    )
  end

  def serialize_product(product)
    {
      id: product.id,
      name: product.name,
      woo_commerce_product_id: product.woo_commerce_product_id,
      price: product.price.to_s,
      stock_quantity: product.stock_quantity,
      description: product.description,
      tags: product.tags,
      active: product.active
    }
  end
end
