require "test_helper"

class ConversationMessageProcessorTest < ActiveSupport::TestCase
  setup { Business.default.update!(category: "perfume") }
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

  test "offers multiple bottles when the requested size is larger than available" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    processor = process_message(pending_order, "100 ml ache?")

    assert_equal :variant_size_unavailable, processor.outcome
    offer = pending_order.conversation.reload.conversation_state.fetch("variant_bundle_offer")
    assert_equal large.id, offer["variant_id"]
    assert_equal 4, offer["quantity"]
    assert_equal "120.0", offer["total_size"]
    assert_predicate pending_order.reload, :collecting_variant?
  end

  test "answers an unavailable size while selecting a named product" do
    product = create_product(name: "The Club", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 390, stock_quantity: 10)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "do you have The Club in 50ml size?")

    assert_equal :variant_size_unavailable, processor.outcome
    assert_equal product, pending_order.reload.product
    assert_predicate pending_order, :collecting_variant?
    assert_equal 2, pending_order.conversation.reload.conversation_state.dig("variant_bundle_offer", "quantity")
  end

  test "acknowledges every unavailable size in a multi-size question" do
    product = create_product(name: "The Club", stock_quantity: 0)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    processor = process_message(pending_order, "50 or 100ml ase?")

    assert_equal :variant_size_unavailable, processor.outcome
    offer = pending_order.conversation.reload.conversation_state.fetch("variant_bundle_offer")
    assert_equal %w[50.0 100.0], offer["requested_sizes"]
  end

  test "treats no during size selection as a size objection" do
    product = create_product(name: "The Club", stock_quantity: 0)
    product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    processor = process_message(pending_order, "no")

    assert_equal :variant_options_rejected, processor.outcome
    assert_predicate pending_order.reload, :collecting_variant?
  end

  test "accepts the remembered multiple-bottle size offer" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)
    process_message(pending_order, "100 ml ache?")

    processor = process_message(pending_order, "yes")

    assert_equal :variant_bundle_selected, processor.outcome
    assert_equal large, pending_order.reload.product_variant
    assert_equal 4, pending_order.quantity
    assert_predicate pending_order, :collecting_name?
    assert_nil pending_order.conversation.reload.conversation_state["variant_bundle_offer"]
  end

  test "selects an available larger variant directly" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    processor = process_message(pending_order, "bigger size")

    assert_equal :order_updated, processor.outcome
    assert_equal large, pending_order.reload.product_variant
    assert_predicate pending_order, :collecting_quantity?
  end

  test "collects a compact size and quantity in the same message" do
    product = create_product(name: "The Blush", stock_quantity: 0)
    variant = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(product: product, status: :collecting_variant)

    processor = process_message(pending_order, "30ml 2")

    assert_equal :multiple_details_collected, processor.outcome
    assert_equal variant, pending_order.reload.product_variant
    assert_equal 2, pending_order.quantity
    assert_predicate pending_order, :collecting_name?
  end

  test "clarifies a currency-only question instead of repeating product prices" do
    product = create_product(name: "The Blush")
    pending_order = create_pending_order(product: product, status: :collecting_quantity)

    processor = process_message(pending_order, "doller?")

    assert_equal :currency_clarification, processor.outcome
    assert_predicate pending_order.reload, :collecting_quantity?
  end

  test "offers another bottle when customer is already on the largest size" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(
      product: product, product_variant: large, status: :collecting_quantity
    )

    processor = process_message(pending_order, "bigger size")

    assert_equal :variant_size_unavailable, processor.outcome
    offer = pending_order.conversation.reload.conversation_state.fetch("variant_bundle_offer")
    assert_equal 2, offer["quantity"]
    assert_equal "60.0", offer["total_size"]
    assert_predicate pending_order.reload, :collecting_quantity?
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
    assert_equal :greeting, process_message(pending_order, "assalamulaikum").outcome
    assert_equal :greeting, process_message(pending_order, "Its a greetings").outcome
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

    [ "show all products", "show me all productsa", "available products", "products dekhao", "ki ki product ache?" ].each do |content|
      assert_equal :product_list_requested, process_message(pending_order, content).outcome, content
    end

    assert_predicate pending_order.reload, :collecting_product?
  end

  test "treats a size-options follow-up as a variant question rather than generic help" do
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "size options?")

    assert_equal :product_variants_requested, processor.outcome
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "understands a short answer to its previous product-for-sizes question" do
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_outcome" => "product_variants_requested" })

    processor = process_message(pending_order, "any product")

    assert_equal :product_variants_requested, processor.outcome
    assert_predicate pending_order.reload, :collecting_product?
  end

  test "uses a named product as the answer to its previous size question without selecting it" do
    create_product(name: "The Office")
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_outcome" => "product_variants_requested" })

    processor = process_message(pending_order, "The Office")

    assert_equal :product_variants_requested, processor.outcome
    assert_nil pending_order.reload.product
    assert_predicate pending_order, :collecting_product?
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

  test "selects from the exact stored product list even when catalog order changes" do
    first = create_product(name: "The Office")
    second = create_product(name: "Bleu Inspired")
    pending_order = create_pending_order(status: :collecting_product)
    ConversationMemory.new(pending_order.conversation).remember_options!(
      kind: :products, records: [ first, second ]
    )

    processor = process_message(pending_order, "2")

    assert_equal :product_selected, processor.outcome
    assert_equal second, pending_order.reload.product
  end

  test "collects a recommended product variant and quantity from one reply" do
    first = create_product(name: "The Office")
    second = create_product(name: "Bleu Inspired", stock_quantity: 0)
    variant = second.product_variants.create!(name: "15 ML", size: "15 ML", price: 480, stock_quantity: 10)
    pending_order = create_pending_order(status: :collecting_product)
    flow = GuidedSalesConversation.new(pending_order.conversation)
    flow.transition!("discover")
    flow.remember_recommendations!([ first.id, second.id ])

    processor = process_message(pending_order, "second one, 15 ML, duita")

    pending_order.reload
    assert_equal :multiple_details_collected, processor.outcome
    assert_equal second, pending_order.product
    assert_equal variant, pending_order.product_variant
    assert_equal 2, pending_order.quantity
    assert_predicate pending_order, :collecting_name?
  end

  test "remembers comparative refinement preferences" do
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "ektu cheaper but stronger kichu chai")

    preferences = pending_order.conversation.reload.conversation_state.fetch("shopping_preferences")
    assert_equal :product_recommendation_requested, processor.outcome
    assert_equal "lower", preferences["price_direction"]
    assert_equal "stronger", preferences["projection_preference"]
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

  test "understands ordinal and positional replies for the offered variants" do
    product = create_product(name: "The Club", stock_quantity: 0)
    small = product.product_variants.create!(name: "10 ML", size: "10 ML", price: 390, stock_quantity: 10)
    product.product_variants.create!(name: "15 ML", size: "15 ML", price: 500, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)

    last_order = create_pending_order(product: product, status: :collecting_variant)
    assert_equal :variant_selected, process_message(last_order, "last one").outcome
    assert_equal large, last_order.reload.product_variant

    third_order = create_pending_order(product: product, status: :collecting_variant)
    assert_equal :variant_selected, process_message(third_order, "3").outcome
    assert_equal large, third_order.reload.product_variant

    first_order = create_pending_order(product: product, status: :collecting_variant)
    assert_equal :variant_selected, process_message(first_order, "first").outcome
    assert_equal small, first_order.reload.product_variant
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

  test "collects comma-separated name phone and address in one message" do
    pending_order = create_pending_order(product: create_product, quantity: 2, status: :collecting_name)

    processor = process_message(pending_order, "Anik, 01712345678, Middle Badda, Dhaka")

    pending_order.reload
    assert_equal :multiple_details_collected, processor.outcome
    assert_equal "Anik", pending_order.customer_name
    assert_equal "01712345678", pending_order.phone
    assert_equal "Middle Badda, Dhaka", pending_order.address
    assert_predicate pending_order, :awaiting_confirmation?
  end

  test "keeps valid bundled details but asks again for an invalid Bangladeshi phone" do
    pending_order = create_pending_order(product: create_product, quantity: 2, status: :collecting_name)

    processor = process_message(pending_order, "Anik, 0199999999, Middle Badda")

    pending_order.reload
    assert_equal :invalid_phone, processor.outcome
    assert_equal "Anik", pending_order.customer_name
    assert_nil pending_order.phone
    assert_equal "Middle Badda", pending_order.address
    assert_predicate pending_order, :collecting_phone?
  end

  test "remembers a product discussed for details without selecting it" do
    product = create_product(name: "The Club")
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer, content: "what are the notes of The Club?"
    )
    processor = ConversationMessageProcessor.new(
      message: message,
      pending_order: pending_order,
      interpretation: ai_interpretation(intent: "product_details", entities: { product_name: "The Club" })
    )

    processor.process

    assert_equal :product_details_requested, processor.outcome
    assert_equal "The Club", pending_order.conversation.reload.conversation_state["last_referenced_product"]
    assert_nil pending_order.reload.product
    assert product.persisted?
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

  test "changes quantity naturally during active checkout without restarting" do
    pending_order = create_pending_order(
      product: create_product(stock_quantity: 10), quantity: 1, status: :collecting_name
    )

    processor = process_message(pending_order, "actually, make it 3")

    assert_equal :order_updated, processor.outcome
    assert_equal 3, pending_order.reload.quantity
    assert_predicate pending_order, :collecting_name?
  end

  test "changes the selected variant while preserving valid checkout progress" do
    product = create_product(name: "The Club", stock_quantity: 0)
    small = product.product_variants.create!(name: "15 ML", size: "15 ML", price: 500, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(
      product: product, product_variant: large, quantity: 2, customer_name: "Anik", status: :collecting_phone
    )
    ConversationMemory.new(pending_order.conversation).remember_options!(
      kind: :variants, records: [ small, large ], product: product
    )

    processor = process_message(pending_order, "actually 15 ML")

    pending_order.reload
    assert_equal :order_updated, processor.outcome
    assert_equal small, pending_order.product_variant
    assert_equal 2, pending_order.quantity
    assert_equal "Anik", pending_order.customer_name
    assert_predicate pending_order, :collecting_phone?
    assert_equal "product_variant", pending_order.change_history.last["field"]
  end

  test "moves to the previous offered variant during active checkout" do
    product = create_product(name: "The Club", stock_quantity: 0)
    small = product.product_variants.create!(name: "10 ML", size: "10 ML", price: 390, stock_quantity: 10)
    medium = product.product_variants.create!(name: "15 ML", size: "15 ML", price: 500, stock_quantity: 10)
    large = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 10)
    pending_order = create_pending_order(
      product: product, product_variant: large, quantity: 1, status: :collecting_name
    )
    ConversationMemory.new(pending_order.conversation).remember_options!(
      kind: :variants, records: [ small, medium, large ], product: product
    )

    process_message(pending_order, "ager ta nibo")

    assert_equal medium, pending_order.reload.product_variant
    assert_predicate pending_order, :collecting_name?
  end

  test "changes product during active checkout and returns to product configuration" do
    club = create_product(name: "The Club")
    oud = create_product(name: "The Oud", stock_quantity: 0)
    oud.product_variants.create!(name: "10 ML", size: "10 ML", price: 420, stock_quantity: 10)
    pending_order = create_pending_order(
      product: club, quantity: 2, customer_name: "Anik", status: :collecting_phone
    )

    processor = process_message(pending_order, "The Club na, The Oud ta den")

    pending_order.reload
    assert_equal :order_updated, processor.outcome
    assert_equal oud, pending_order.product
    assert_nil pending_order.quantity
    assert_equal "Anik", pending_order.customer_name
    assert_predicate pending_order, :collecting_variant?
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

  test "accepts a valid phone from raw content when AI redacts the entity" do
    pending_order = create_pending_order(product: create_product, quantity: 1, customer_name: "Anik",
      status: :collecting_phone)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "01725126467")
    interpretation = ai_interpretation(intent: "provide_phone", entities: { phone: "[PHONE]" })

    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order,
      interpretation: interpretation)
    processor.process

    assert_equal :phone_collected, processor.outcome
    assert_equal "01725126467", pending_order.reload.phone
    assert_predicate pending_order, :collecting_address?
  end

  test "changes a phone during checkout using the number in raw content" do
    pending_order = create_pending_order(product: create_product, quantity: 1, customer_name: "Anik",
      status: :collecting_phone)
    message = pending_order.conversation.messages.create!(sender_type: :customer,
      content: "change phone to 01712345678")
    interpretation = ai_interpretation(intent: "change_phone", entities: { phone: "[PHONE]" })

    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order,
      interpretation: interpretation)
    processor.process

    assert_equal :order_updated, processor.outcome
    assert_equal "01712345678", pending_order.reload.phone
  end

  test "treats never trying a scent as guidance rather than a sample request" do
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "woody try kori nai kokhon o")

    assert_equal :first_time_scent_guidance, processor.outcome
  end

  test "recognizes a contextual weather question" do
    product = create_product(name: "The Club")
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_referenced_product" => product.name })

    processor = process_message(pending_order, "kon weather er jonno perfect eita?")

    assert_equal :product_weather_requested, processor.outcome
  end

  test "resolves the previous product from turn-manager reference history" do
    first = create_product(name: "The Office")
    second = create_product(name: "The Oud")
    pending_order = create_pending_order(product: second, status: :collecting_product)
    pending_order.conversation.update!(conversation_state: {
      "turn_manager" => {
        "reference" => { "product_id" => second.id, "product_name" => second.name },
        "reference_history" => [
          { "product_id" => first.id, "product_name" => first.name },
          { "product_id" => second.id, "product_name" => second.name }
        ]
      }
    })

    processor = process_message(pending_order, "not this, the previous product")

    assert_equal :product_selected, processor.outcome
    assert_equal first, pending_order.reload.product
  end

  test "does not repeat the same long recommendation for identical follow-up input" do
    pending_order = create_pending_order(status: :collecting_product)
    pending_order.conversation.update!(conversation_state: { "last_outcome" => "product_recommendation_requested" })
    pending_order.conversation.messages.create!(sender_type: :customer, content: "oud")

    processor = process_message(pending_order, "oud")

    assert_equal :recommendation_choice_reminder, processor.outcome
  end

  test "atomically collects product size quantity and preserves a delivery question" do
    product = create_product(name: "The Oud", stock_quantity: 0)
    variant = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 8)
    pending_order = create_pending_order(status: :collecting_product)

    processor = process_message(pending_order, "The Oud 30ml two bottles, delivery charge koto?")

    assert_equal :multiple_details_collected, processor.outcome
    assert_equal [ :delivery_charge_requested ], processor.secondary_outcomes
    assert_equal product, pending_order.reload.product
    assert_equal variant, pending_order.product_variant
    assert_equal 2, pending_order.quantity
    assert_predicate pending_order, :collecting_name?
  end

  test "uses the positive product when customer corrects product in a multi-action message" do
    rejected = create_product(name: "The Oud", stock_quantity: 0)
    rejected.product_variants.create!(name: "10 ML", size: "10 ML", price: 420, stock_quantity: 5)
    selected = create_product(name: "The Office", stock_quantity: 0)
    variant = selected.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 5)
    pending_order = create_pending_order(product: rejected, status: :collecting_variant)

    processor = process_message(pending_order, "Not The Oud, give The Office 10ml two bottles")

    assert_equal :multiple_details_collected, processor.outcome
    assert_equal selected, pending_order.reload.product
    assert_equal variant, pending_order.product_variant
    assert_equal 2, pending_order.quantity
  end

  test "does not partially apply a multi-action plan when requested stock is unavailable" do
    current = create_product(name: "The Oud")
    selected = create_product(name: "The Office", stock_quantity: 0)
    selected.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 1)
    pending_order = create_pending_order(product: current, status: :collecting_quantity)

    process_message(pending_order, "give The Office 10ml two bottles")

    assert_equal current, pending_order.reload.product
    assert_nil pending_order.product_variant
    assert_nil pending_order.quantity
  end

  test "does not save an acceptance phrase as the customer name" do
    pending_order = create_pending_order(product: create_product, quantity: 1, status: :collecting_name)

    processor = process_message(pending_order, "that works for me")

    assert_equal :name_required, processor.outcome
    assert_nil pending_order.reload.customer_name
    assert_predicate pending_order, :collecting_name?
  end

  test "selects an exact catalog product before a recommendation intent can override it" do
    product = create_product(name: "The Office")
    pending_order = create_pending_order(status: :collecting_product)
    message = pending_order.conversation.messages.create!(sender_type: :customer, content: "The Office")
    interpretation = ai_interpretation(intent: "product_recommendation")

    processor = ConversationMessageProcessor.new(
      message: message, pending_order: pending_order, interpretation: interpretation
    )
    processor.process

    assert_equal :product_selected, processor.outcome
    assert_equal product, pending_order.reload.product
    assert_predicate pending_order, :collecting_quantity?
  end

  test "applies size quantity and name atomically while collecting checkout details" do
    product = create_product(name: "The Office", stock_quantity: 0)
    product.product_variants.create!(name: "10 ML", size: "10 ML", price: 350, stock_quantity: 8)
    selected = product.product_variants.create!(name: "30 ML", size: "30 ML", price: 850, stock_quantity: 8)
    pending_order = create_pending_order(product: product, quantity: 1, status: :collecting_name)
    message = pending_order.conversation.messages.create!(
      sender_type: :customer, content: "Salam, 30 ml 1 ta den bhai, 10 ml na"
    )

    processor = ConversationMessageProcessor.new(message: message, pending_order: pending_order)
    processor.process

    assert_equal :multiple_details_collected, processor.outcome
    assert_equal selected, pending_order.reload.product_variant
    assert_equal 1, pending_order.quantity
    assert_equal "Salam", pending_order.customer_name
    assert_predicate pending_order, :collecting_phone?
  end

  test "reuses a previous completed order phone number before AI can redirect the turn" do
    conversation = Conversation.create!(channel: "facebook", external_customer_id: SecureRandom.uuid)
    conversation.create_pending_order!(
      product: create_product, quantity: 1, customer_name: "Anik", phone: "01712345678",
      address: "Dhaka", status: :confirmed
    )
    pending_order = conversation.create_pending_order!(
      product: create_product(name: "The Oud"), quantity: 1, customer_name: "Anik", status: :collecting_phone
    )

    processor = process_message(pending_order, "ager number tai den bhai")

    assert_equal :phone_collected, processor.outcome
    assert_equal "01712345678", pending_order.reload.phone
    assert_predicate pending_order, :collecting_address?
  end

  test "updates a customer name expressed naturally while reviewing the order" do
    pending_order = create_ready_pending_order(customer_name: "that works for me", status: :awaiting_confirmation)

    processor = process_message(pending_order, "my name is Salam update on the order")

    assert_equal :order_updated, processor.outcome
    assert_equal "Salam", pending_order.reload.customer_name
  end

  test "separates a return policy question from a return request" do
    pending_order = create_ready_pending_order(status: :confirmed)

    processor = process_message(pending_order, "return policy ase?")

    assert_equal :return_policy_requested, processor.outcome
    assert_predicate pending_order.reload, :confirmed?
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
