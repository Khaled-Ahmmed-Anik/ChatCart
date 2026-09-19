# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

business = Business.default
business.create_business_policy! unless business.business_policy
business.create_delivery_integration! unless business.delivery_integration

if ENV["PLATFORM_ADMIN_EMAIL"].present? && ENV["PLATFORM_ADMIN_PASSWORD"].present?
  administrator = PlatformAdministrator.find_or_initialize_by(email: ENV["PLATFORM_ADMIN_EMAIL"])
  administrator.name = "ChatCart Platform Administrator"
  administrator.password = ENV["PLATFORM_ADMIN_PASSWORD"]
  administrator.active = true
  administrator.save!
end

if ENV["CHATCART_OWNER_EMAIL"].present? && ENV["CHATCART_OWNER_PASSWORD"].present?
  owner = business.users.find_or_initialize_by(email: ENV["CHATCART_OWNER_EMAIL"])
  _token, token_digest = User.issue_token if owner.api_token_digest.blank?
  owner.assign_attributes(
    name: "ChatCart Business Owner",
    role: "owner",
    active: true,
    api_token_digest: owner.api_token_digest.presence || token_digest
  )
  owner.password = ENV["CHATCART_OWNER_PASSWORD"]
  owner.save!
end

default_products = [
  {
    name: "The Blush",
    price: 999,
    stock_quantity: 10,
    description: "A soft, sweet scent with a warm, skin-like finish. Gentle, comforting, and quietly magnetic.",
    tags: "soft,sweet,warm,gentle,comforting",
    active: true
  },
  {
    name: "The Desire",
    price: 999,
    stock_quantity: 10,
    description: "A smooth blend of soft sweetness and warm depth. Sensual, inviting, and quietly addictive.",
    tags: "sweet,warm,sensual,inviting,evening",
    active: true
  },
  {
    name: "The Club",
    price: 999,
    stock_quantity: 10,
    description: "Smells like rich tobacco blended with smooth vanilla. Bold yet refined, designed for long nights and strong presence.",
    tags: "tobacco,vanilla,bold,refined,night",
    active: true
  },
  {
    name: "The Party",
    price: 999,
    stock_quantity: 10,
    description: "A modern, vibrant scent with bold and sweet energy. Expressive and confident, made for standout moments.",
    tags: "party,sweet,vibrant,bold,confident",
    active: true
  },
  {
    name: "The Office",
    price: 920,
    stock_quantity: 10,
    description: "Inspired by fresh aquatic notes with a clean finish. Subtle, professional, and confident from morning to evening.",
    tags: "fresh,aquatic,clean,professional,office",
    active: true
  }
]

default_products.each do |attributes|
  product = business.products.find_or_initialize_by(name: attributes[:name])
  product.assign_attributes(attributes)
  product.save!
end

business.products.where(name: [ "Fresh Musk", "Vanilla Night", "Royal Oud" ]).update_all(active: false)
