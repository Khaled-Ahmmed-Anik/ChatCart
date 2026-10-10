class ConversationToolGateway
  class UnsupportedTool < StandardError; end

  POLICY_FIELDS = %w[
    payment_methods cash_on_delivery delivery_charges delivery_areas delivery_time
    return_policy replacement_policy refund_policy discount_policy authenticity_statement
    trust_information trial_policy
  ].freeze
  MAX_RESULTS = 3

  TOOL_DEFINITIONS = [
    {
      name: "search_products",
      description: "Find active in-stock products in the current business catalogue.",
      parameters: {
        type: "OBJECT",
        properties: {
          query: { type: "STRING", description: "Customer product words, preferences, or budget." },
          limit: { type: "INTEGER", minimum: 1, maximum: MAX_RESULTS }
        },
        required: [ "query" ]
      }
    },
    {
      name: "search_business_knowledge",
      description: "Search approved descriptive product guidance, FAQs, and policies for the current business.",
      parameters: {
        type: "OBJECT",
        properties: {
          query: { type: "STRING", description: "The customer's descriptive question or preference." },
          limit: { type: "INTEGER", minimum: 1, maximum: MAX_RESULTS }
        },
        required: [ "query" ]
      }
    },
    {
      name: "get_product_details",
      description: "Get grounded details for one product in the current business.",
      parameters: {
        type: "OBJECT",
        properties: {
          product_id: { type: "INTEGER" },
          product_name: { type: "STRING" }
        }
      }
    },
    {
      name: "get_variant_availability",
      description: "List active in-stock size or variant choices for one product.",
      parameters: {
        type: "OBJECT",
        properties: { product_id: { type: "INTEGER" } },
        required: [ "product_id" ]
      }
    },
    {
      name: "get_business_policy",
      description: "Read an approved sales, payment, delivery, or after-sales policy.",
      parameters: {
        type: "OBJECT",
        properties: { topic: { type: "STRING", enum: POLICY_FIELDS } },
        required: [ "topic" ]
      }
    },
    {
      name: "get_order_summary",
      description: "Read the current pending order without exposing customer contact details.",
      parameters: { type: "OBJECT", properties: {} }
    }
  ].freeze

  def self.definitions
    TOOL_DEFINITIONS
  end

  def initialize(conversation:, pending_order:)
    @conversation = conversation
    @pending_order = pending_order
  end

  def call(name, arguments = {})
    arguments = arguments.to_h.with_indifferent_access
    result = case name.to_s
    when "search_products" then search_products(arguments)
    when "search_business_knowledge" then search_business_knowledge(arguments)
    when "get_product_details" then get_product_details(arguments)
    when "get_variant_availability" then get_variant_availability(arguments)
    when "get_business_policy" then get_business_policy(arguments)
    when "get_order_summary" then order_summary
    else raise UnsupportedTool, "Unsupported conversation tool: #{name}"
    end

    { "tool" => name.to_s, "result" => result }
  end

  private

  attr_reader :conversation, :pending_order
  delegate :business, to: :conversation

  def search_products(arguments)
    limit = arguments[:limit].to_i.clamp(1, MAX_RESULTS)
    result = ProductRecommendationService.new(
      business: business,
      message: arguments.fetch(:query),
      preferences: conversation.conversation_state.to_h["shopping_preferences"],
      limit: limit
    ).call
    {
      "matches" => result.offers.map { |offer| offer_payload(offer) },
      "exact_budget_match" => result.exact_match,
      "minimum_available_price" => decimal(result.minimum_price)
    }.compact
  end

  def get_product_details(arguments)
    product = scoped_product(arguments)
    return { "found" => false } if product.blank?

    {
      "found" => true,
      "id" => product.id,
      "name" => product.name,
      "type" => product.product_type,
      "starting_price" => decimal(product.starting_price),
      "stock_quantity" => product.total_available_stock,
      "short_description" => product.short_description,
      "description" => product.description,
      "benefits" => product.benefits,
      "suitable_for" => product.suitable_for,
      "attributes" => product.product_attributes.to_h
    }.compact
  end

  def search_business_knowledge(arguments)
    limit = arguments[:limit].to_i.clamp(1, MAX_RESULTS)
    results = HybridBusinessKnowledgeRetriever.new(
      business: business, query: arguments.fetch(:query), limit: limit
    ).call
    {
      "matches" => results.map do |result|
        {
          "title" => result.document.title,
          "content" => result.document.content.truncate(800),
          "citation" => result.citation,
          "retrieval_score" => result.score
        }
      end
    }
  end

  def get_variant_availability(arguments)
    product = business.products.available_for_sale.find_by(id: arguments[:product_id])
    return { "found" => false, "variants" => [] } if product.blank?

    {
      "found" => true,
      "product_id" => product.id,
      "product_name" => product.name,
      "variants" => product.available_variants.limit(10).map do |variant|
        {
          "id" => variant.id,
          "name" => variant.display_name,
          "price" => decimal(variant.price),
          "stock_quantity" => variant.stock_quantity
        }
      end
    }
  end

  def get_business_policy(arguments)
    topic = arguments.fetch(:topic).to_s
    raise ArgumentError, "Unsupported policy topic" unless topic.in?(POLICY_FIELDS)

    { "topic" => topic, "configured" => business.policy.public_send(topic).present?, "value" => business.policy.public_send(topic) }
  end

  def order_summary
    {
      "status" => pending_order.status,
      "product_id" => pending_order.product_id,
      "product_name" => pending_order.product&.name,
      "variant_id" => pending_order.product_variant_id,
      "variant_name" => pending_order.product_variant&.display_name,
      "quantity" => pending_order.quantity,
      "items" => pending_order.item_snapshot,
      "unit_price" => pending_order.product.present? ? decimal(pending_order.unit_price) : nil,
      "total_price" => pending_order.product.present? && pending_order.quantity.present? ? decimal(pending_order.total_price) : nil,
      "has_customer_name" => pending_order.customer_name.present?,
      "has_phone" => pending_order.phone.present?,
      "has_address" => pending_order.address.present?
    }.compact
  end

  def scoped_product(arguments)
    return business.products.available_for_sale.find_by(id: arguments[:product_id]) if arguments[:product_id].present?
    return if arguments[:product_name].blank?

    resolution = ProductResolutionService.new(business: business, query: arguments[:product_name]).resolve
    resolution.product if resolution.matched?
  end

  def offer_payload(offer)
    {
      "product_id" => offer.product.id,
      "product_name" => offer.product.name,
      "variant_id" => offer.variant&.id,
      "variant_name" => offer.variant&.display_name,
      "price" => decimal(offer.price),
      "stock_quantity" => offer.stock_quantity
    }.compact
  end

  def decimal(value)
    return if value.blank?

    value.to_d.to_s("F")
  end
end
