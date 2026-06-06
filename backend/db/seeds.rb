# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

Product.find_or_create_by!(name: "Fresh Musk") do |product|
  product.price = 750
  product.stock_quantity = 10
  product.tags = "fresh,office,daily,musk"
end

Product.find_or_create_by!(name: "Vanilla Night") do |product|
  product.price = 900
  product.stock_quantity = 6
  product.tags = "sweet,vanilla,evening,warm"
end

Product.find_or_create_by!(name: "Royal Oud") do |product|
  product.price = 1200
  product.stock_quantity = 4
  product.tags = "oud,woody,premium,strong"
end
