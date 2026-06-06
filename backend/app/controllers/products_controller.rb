class ProductsController < ApplicationController
  def index
    products = Product.active.in_stock.order(:name)

    render json: products.map { |product| serialize_product(product) }
  end

  private

  def serialize_product(product)
    {
      id: product.id,
      name: product.name,
      woo_commerce_product_id: product.woo_commerce_product_id,
      price: product.price.to_s,
      stock_quantity: product.stock_quantity,
      description: product.description,
      tags: product.tags
    }
  end
end
