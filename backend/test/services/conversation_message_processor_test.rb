require "test_helper"

class ConversationMessageProcessorTest < ActiveSupport::TestCase
  test "collects product by matching active in-stock product name" do
    product = create_product(name: "Fresh Musk")
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "I want Fresh Musk please"
    )

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_equal product, pending_order.reload.product
    assert_predicate pending_order, :collecting_quantity?
  end

  test "collects a product variant before quantity and uses variant stock" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "3 ml", size: "3 ml", price: 250, stock_quantity: 2)
    product.product_variants.create!(name: "6 ml", size: "6 ml", price: 450, stock_quantity: 5)
    pending_order = create_pending_order(status: :collecting_product)

    process_message(pending_order, "I want The Oud")
    assert_predicate pending_order.reload, :collecting_variant?

    processor = process_message(pending_order, "6 ml")
    assert_equal :variant_selected, processor.outcome
    assert_equal "6 ml", pending_order.reload.product_variant.size
    assert_predicate pending_order, :collecting_quantity?

    unavailable = process_message(pending_order, "6")
    assert_equal :quantity_unavailable, unavailable.outcome
    assert_predicate pending_order.reload, :collecting_quantity?
    assert_equal 5, pending_order.product_variant.stock_quantity
  end

  test "does not collect inactive or out of stock product" do
    create_product(name: "Fresh Musk", active: false, stock_quantity: 10)
    create_product(name: "Royal Oud", active: true, stock_quantity: 0)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "I want Fresh Musk or Royal Oud"
    )

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.product
    assert_predicate pending_order, :collecting_product?
  end

  test "collects quantity when stock is available" do
    product = create_product(stock_quantity: 3)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "2")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_equal 2, pending_order.reload.quantity
    assert_predicate pending_order, :collecting_name?
  end

  test "collects a naturally written quantity" do
    product = create_product(stock_quantity: 5)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    processor = process_message(pending_order, "I would like two bottles please")

    assert_equal 2, pending_order.reload.quantity
    assert_predicate pending_order, :collecting_name?
    assert_equal :quantity_collected, processor.outcome
  end

  test "does not collect quantity beyond stock" do
    product = create_product(stock_quantity: 1)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "2")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.quantity
    assert_predicate pending_order, :collecting_quantity?
  end

  test "explains invalid and unavailable quantities through outcomes" do
    product = create_product(stock_quantity: 2)
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    assert_equal :invalid_quantity, process_message(pending_order, "a few").outcome
    assert_equal :quantity_unavailable, process_message(pending_order, "5").outcome
    assert_nil pending_order.reload.quantity
  end

  test "answers conversational intents without advancing the order" do
    pending_order = create_pending_order(status: :collecting_product)

    assert_equal :greeting, process_message(pending_order, "Hello!").outcome
    assert_equal :help, process_message(pending_order, "Can you help me?").outcome
    assert_equal :thanks, process_message(pending_order, "Thank you").outcome
    assert_equal :price_inquiry, process_message(pending_order, "What is the price of Fresh Musk?").outcome
    assert_equal :stock_inquiry, process_message(pending_order, "Is Fresh Musk available?").outcome
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "recognizes a direct product comparison without AI" do
    create_product(name: "The Office")
    create_product(name: "Bleu Inspired")
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "The Office vs Bleu Inspired, which is better?")

    assert_equal :product_comparison_requested, processor.outcome
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "recognizes requests to show the full product list without AI" do
    pending_order = create_pending_order(status: :collecting_product)

    [ "show all products", "available products", "products dekhao", "ki ki product ache?" ].each do |content|
      assert_equal :product_list_requested, process_message(pending_order, content).outcome, content
    end

    assert_predicate pending_order.reload, :collecting_product?
  end

  test "remembers guided fragrance preferences across messages" do
    pending_order = create_pending_order(status: :collecting_product)

    assert_equal :product_recommendation_requested, process_message(pending_order, "suggest a combo").outcome
    assert_equal :product_recommendation_requested, process_message(pending_order, "for him, fresh and woody for office").outcome

    preferences = pending_order.conversation.reload.conversation_state.fetch("shopping_preferences")
    assert_equal "combo", preferences["format"]
    assert_equal "men", preferences["audience"]
    assert_equal %w[fresh woody], preferences["scent_families"]
    assert_equal [ "office" ], preferences["occasions"]
  end

  test "leaves size selection when customer asks to browse and understands ekta as single perfume" do
    product = create_product(name: "The Office", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    browse = process_message(pending_order, "we will decide later, give me some options")

    assert_equal :product_recommendation_requested, browse.outcome
    assert_predicate pending_order.reload, :collecting_product?
    assert_nil pending_order.product

    choose_single = process_message(pending_order, "ekta")

    assert_equal :product_recommendation_requested, choose_single.outcome
    assert_equal "single", pending_order.conversation.reload.conversation_state.dig("shopping_preferences", "format")
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "recovers single-product context from an earlier bot prompt created before preference memory" do
    product = create_product(name: "The Office", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)
    pending_order.conversation.messages.create!(
      sender_type: :bot,
      content: "Apni ki ekta perfume niben naki multiple fragrances er kono combo niben?"
    )

    processor = process_message(pending_order, "ekta nibo")

    assert_equal :product_recommendation_requested, processor.outcome
    assert_predicate pending_order.reload, :collecting_product?
    assert_nil pending_order.product
    assert_equal "single", pending_order.conversation.reload.conversation_state.dig("shopping_preferences", "format")
  end

  test "rejects previous recommendations and does not lose discovery context" do
    pending_order = create_pending_order(status: :collecting_product)
    flow = GuidedSalesConversation.new(pending_order.conversation)
    flow.transition!("discover")
    flow.remember_recommendations!([ 11, 12 ])

    processor = process_message(pending_order, "Egula pochondo hoy nai")

    assert_equal :recommendations_rejected, processor.outcome
    assert_equal [ 11, 12 ], flow.context["rejected_product_ids"]
    assert_equal [ 11, 12 ], pending_order.conversation.reload.conversation_state.dig("shopping_preferences", "rejected_product_ids")
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "rejects earlier options and applies a corrected scent preference in the same message" do
    first = create_product(name: "Bleu Inspired")
    second = create_product(name: "The Blush")
    pending_order = create_pending_order(status: :collecting_product)
    flow = GuidedSalesConversation.new(pending_order.conversation)
    flow.transition!("discover")
    flow.remember_recommendations!([ first.id, second.id ])

    processor = process_message(pending_order, "no one, something oudy")

    assert_equal :product_recommendation_requested, processor.outcome
    state = pending_order.conversation.reload.conversation_state
    assert_equal [ first.id, second.id ], state.dig("guided_sales", "context", "rejected_product_ids")
    assert_includes state.dig("shopping_preferences", "scent_families"), "oud"
    assert_equal [ first.id, second.id ], state.dig("shopping_preferences", "rejected_product_ids")
  end

  test "recognizes a misspelled oud preference without AI" do
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "I need something oddy")

    assert_equal :product_recommendation_requested, processor.outcome
    assert_includes pending_order.conversation.reload.conversation_state.dig("shopping_preferences", "scent_families"), "oud"
  end

  test "adds a referenced recommendation to the shortlist" do
    first = create_product(name: "The Office")
    second = create_product(name: "Bleu Inspired")
    pending_order = create_pending_order(status: :collecting_product)
    flow = GuidedSalesConversation.new(pending_order.conversation)
    flow.transition!("discover")
    flow.remember_recommendations!([ first.id, second.id ])

    processor = process_message(pending_order, "keep the second one")

    assert_equal :shortlist_updated, processor.outcome
    assert_equal [ second.id ], flow.context["shortlist_product_ids"]
  end

  test "resumes an order after temporarily browsing recommendations" do
    product = create_product(name: "The Office")
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    process_message(pending_order, "give me some options")
    assert_predicate pending_order.reload, :collecting_product?

    processor = process_message(pending_order, "continue my order")

    assert_equal :resume_order_requested, processor.outcome
    assert_equal product, pending_order.reload.product
    assert_predicate pending_order, :collecting_quantity?
  end

  test "suspends checkout cleanly while browsing and restores the exact checkout step" do
    product = create_product(name: "The Office")
    pending_order = create_pending_order(
      product: product, quantity: 2, customer_name: "Anik", status: :collecting_phone
    )

    process_message(pending_order, "show me some options")

    assert_predicate pending_order.reload, :collecting_product?
    assert_nil pending_order.product

    process_message(pending_order, "back to my order")

    assert_equal product, pending_order.reload.product
    assert_equal 2, pending_order.quantity
    assert_equal "Anik", pending_order.customer_name
    assert_predicate pending_order, :collecting_phone?
  end

  test "selects a product using its position in the latest recommendations" do
    first = create_product(name: "The Office")
    second = create_product(name: "Bleu Inspired")
    pending_order = create_pending_order(status: :collecting_product)
    flow = GuidedSalesConversation.new(pending_order.conversation)
    flow.transition!("discover")
    flow.remember_recommendations!([ first.id, second.id ])

    processor = process_message(pending_order, "second one nibo")

    assert_equal :product_selected, processor.outcome
    assert_equal second, pending_order.reload.product
    assert_predicate pending_order, :collecting_quantity?
  end

  test "understands relative size and price replies" do
    product = create_product(name: "The Office", stock_quantity: 0)
    small = product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10, position: 3)
    medium = product.product_variants.create!(name: "15 ML", size: "15 ML", price: 480, stock_quantity: 10, position: 2)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10, position: 1)

    best_value_order = create_pending_order(product: product, status: :collecting_variant)
    process_message(best_value_order, "boro ta, best value")
    assert_equal large, best_value_order.reload.product_variant

    price_order = create_pending_order(product: product, status: :collecting_variant)
    process_message(price_order, "480 er ta")
    assert_equal medium, price_order.reload.product_variant

    small_order = create_pending_order(product: product, status: :collecting_variant)
    process_message(small_order, "choto ta")
    assert_equal small, small_order.reload.product_variant
  end

  test "understands Banglish quantity words during quantity collection" do
    pending_order = create_pending_order(product: create_product, status: :collecting_quantity)

    processor = process_message(pending_order, "duita nibo")

    assert_equal :quantity_collected, processor.outcome
    assert_equal 2, pending_order.reload.quantity
  end

  test "collects name, phone, and address then awaits confirmation" do
    pending_order = create_pending_order(
      product: create_product,
      quantity: 1,
      status: :collecting_name
    )

    process_message(pending_order, "Khaled Ahmed")
    assert_equal "Khaled Ahmed", pending_order.reload.customer_name
    assert_predicate pending_order, :collecting_phone?

    process_message(pending_order, "+8801712345678")
    assert_equal "+8801712345678", pending_order.reload.phone
    assert_predicate pending_order, :collecting_address?

    process_message(pending_order, "House 10, Road 2, Dhaka")
    assert_equal "House 10, Road 2, Dhaka", pending_order.reload.address
    assert_predicate pending_order, :awaiting_confirmation?
    assert pending_order.ready_for_confirmation?
  end

  test "ignores non-customer messages" do
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :bot, content: "Fresh Musk")

    ConversationMessageProcessor.new(message: message, pending_order: pending_order).process

    assert_nil pending_order.reload.product
  end

  test "confirms an order awaiting confirmation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    process_message(pending_order, "confirm")

    assert_predicate pending_order.reload, :confirmed?
  end

  test "cancels an order awaiting confirmation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    process_message(pending_order, "cancel")

    assert_predicate pending_order.reload, :cancelled?
  end

  test "keeps awaiting confirmation for unclear confirmation reply" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    process_message(pending_order, "maybe later")

    assert_predicate pending_order.reload, :awaiting_confirmation?
  end

  test "keeps the order pending when the customer will confirm later" do
    [ "I will confirm later", "will confirm letter", "pore confirm korbo", "ekhon na" ].each do |content|
      pending_order = create_ready_pending_order(status: :awaiting_confirmation)

      processor = process_message(pending_order, content)

      assert_equal :confirmation_deferred, processor.outcome, content
      assert_predicate pending_order.reload, :awaiting_confirmation?, content
    end
  end

  test "recognizes change the order while awaiting confirmation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    processor = process_message(pending_order, "change the order")

    assert_equal :order_change_requested, processor.outcome
    assert_predicate pending_order.reload, :awaiting_confirmation?
  end

  test "updates order details using natural correction commands" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    processor = process_message(pending_order, "change quantity to 3")

    assert_equal :order_updated, processor.outcome
    assert_equal 3, pending_order.reload.quantity
    assert_predicate pending_order, :awaiting_confirmation?
    assert_equal "quantity", pending_order.change_history.sole.fetch("field")
    assert_equal "1", pending_order.change_history.sole.fetch("from")
    assert_equal "3", pending_order.change_history.sole.fetch("to")
    assert pending_order.change_history.sole.fetch("changed_at").present?
    assert pending_order.change_history.sole.fetch("message_id").present?
  end

  test "explains how to update a confirmed order" do
    pending_order = create_ready_pending_order(status: :confirmed)

    processor = process_message(pending_order, "change my previous order")

    assert_equal :order_change_requested, processor.outcome
    assert_predicate pending_order.reload, :confirmed?
    assert_empty pending_order.change_history
  end

  test "updates and reopens a confirmed order for confirmation" do
    pending_order = create_ready_pending_order(status: :confirmed)

    processor = process_message(pending_order, "change phone to 01812345678")

    pending_order.reload
    assert_equal :confirmed_order_updated, processor.outcome
    assert_equal "01812345678", pending_order.phone
    assert_predicate pending_order, :awaiting_confirmation?
    assert_equal(
      { "field" => "phone", "from" => "+8801712345678", "to" => "01812345678" },
      pending_order.change_history.sole.slice("field", "from", "to")
    )
  end

  test "does not update an order submitted to WooCommerce" do
    pending_order = create_ready_pending_order(status: :submitted_to_woocommerce)

    processor = process_message(pending_order, "change quantity to 3")

    assert_equal :submitted_order_change_requested, processor.outcome
    assert_equal 1, pending_order.reload.quantity
    assert_empty pending_order.change_history
  end

  test "does not update a cancelled order" do
    pending_order = create_ready_pending_order(status: :cancelled)

    processor = process_message(pending_order, "change address to Chattogram")

    assert_equal :cancelled_order_change_requested, processor.outcome
    assert_equal "Dhaka", pending_order.reload.address
    assert_empty pending_order.change_history
  end

  test "restarts an order without creating a new conversation" do
    pending_order = create_ready_pending_order(status: :awaiting_confirmation)

    processor = process_message(pending_order, "new order")

    pending_order.reload
    assert_equal :restarted, processor.outcome
    assert_predicate pending_order, :collecting_product?
    assert_nil pending_order.product
    assert_nil pending_order.quantity
    assert_nil pending_order.customer_name
  end

  test "collects multiple explicitly extracted details from one message" do
    product = create_product(name: "Fresh Musk", stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer,
      content: "Fresh Musk 2 ta, name Khaled, phone 01712345678, address Dhaka"
    )
    interpretation = ai_interpretation(
      intent: "select_product",
      entities: {
        product_name: product.name,
        quantity: 2,
        customer_name: "Khaled",
        phone: "01712345678",
        address: "Dhaka"
      }
    )

    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: interpretation
    )
    processor.process

    pending_order.reload
    assert_equal :multiple_details_collected, processor.outcome
    assert_equal product, pending_order.product
    assert_equal 2, pending_order.quantity
    assert_equal "Khaled", pending_order.customer_name
    assert_equal "01712345678", pending_order.phone
    assert_equal "Dhaka", pending_order.address
    assert_predicate pending_order, :awaiting_confirmation?
  end

  test "routes a confident conversational AI intent without changing the order" do
    pending_order = create_ready_pending_order(status: :confirmed)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "kemon asen?")
    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: ai_interpretation(intent: "wellbeing")
    )

    processor.process

    assert_equal :wellbeing, processor.outcome
    assert_predicate pending_order.reload, :confirmed?
  end

  test "asks for clarification when AI confidence is low" do
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "oi ta den")
    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: ai_interpretation(intent: "select_product", confidence: 0.4, needs_clarification: true)
    )

    processor.process

    assert_equal :clarification_needed, processor.outcome
    assert_nil pending_order.reload.product
  end

  test "exposes informational secondary outcomes without executing another order action" do
    product = create_product(name: "Fresh Musk")
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer, content: "Fresh Musk, delivery charge koto?"
    )
    interpretation = ai_interpretation(
      intent: "select_product",
      entities: { product_name: product.name },
      secondary_intents: %w[delivery_charge change_quantity]
    )
    processor = ConversationMessageProcessor.new(
      message: message, pending_order: pending_order, interpretation: interpretation
    )

    processor.process

    assert_equal :product_selected, processor.outcome
    assert_equal [ :delivery_charge_requested ], processor.secondary_outcomes
    assert_equal product, pending_order.reload.product
    assert_nil pending_order.quantity
  end

  test "reuses remembered customer details only when explicitly requested" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    product = create_product
    conversation.create_pending_order!(
      product: product, quantity: 1, customer_name: "Khaled", phone: "01712345678",
      address: "Badda, Dhaka", status: :confirmed
    )
    current = conversation.create_pending_order!(product: product, quantity: 2, status: :collecting_name)

    process_message(current, "same name")
    process_message(current, "same phone")
    process_message(current, "same address")

    current.reload
    assert_equal "Khaled", current.customer_name
    assert_equal "01712345678", current.phone
    assert_equal "Badda, Dhaka", current.address
    assert_predicate current, :awaiting_confirmation?
  end

  private

  def process_message(pending_order, content)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: content)
    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order)
    processor.process
    processor
  end

  def create_pending_order(attributes = {})
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.create_pending_order!(attributes)
  end

  def create_product(attributes = {})
    Product.create!(
      {
        name: "Fresh Musk",
        price: 750,
        stock_quantity: 10
      }.merge(attributes)
    )
  end

  def create_ready_pending_order(attributes = {})
    create_pending_order(
      {
        product: create_product,
        quantity: 1,
        customer_name: "Khaled",
        phone: "+8801712345678",
        address: "Dhaka"
      }.merge(attributes)
    )
  end

  def ai_interpretation(intent:, entities: {}, confidence: 0.95, needs_clarification: false, possible_intents: [], secondary_intents: [])
    AiIntentClassifier::Result.new(
      intent: intent,
      secondary_intents: secondary_intents,
      confidence: confidence,
      entities: entities.with_indifferent_access,
      language: "banglish",
      sentiment: "neutral",
      needs_clarification: needs_clarification,
      possible_intents: possible_intents
    )
  end
end
