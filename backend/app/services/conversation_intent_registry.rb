class ConversationIntentRegistry
  GROUPS = {
    social: %w[
      greeting wellbeing thanks goodbye help bot_identity language_preference unclear complaint human_agent
    ],
    products: %w[
      list_products product_search product_details product_price product_availability product_recommendation
      compare_products product_variants product_images out_of_stock alternative_product gift_recommendation
      refine_recommendation reject_recommendations shortlist_add shortlist_remove shortlist_show
    ],
    ordering: %w[
      new_order repeat_order select_product select_quantity provide_name provide_phone provide_address
      review_order confirm_order cancel_order resume_order defer_confirmation browse_products go_back
    ],
    updates: %w[
      change_product change_quantity change_name change_phone change_address order_details order_history
      change_confirmed_order
    ],
    payment_and_delivery: %w[
      payment_methods cash_on_delivery delivery_charge delivery_area delivery_time order_status
    ],
    after_sales: %w[return_request replacement_request refund_request]
  }.freeze

  INTENTS = GROUPS.values.flatten.freeze
  MUTATING_INTENTS = %w[
    new_order repeat_order select_product select_quantity provide_name provide_phone provide_address
    confirm_order cancel_order change_product change_quantity change_name change_phone change_address
    change_confirmed_order
  ].freeze
  INFORMATIONAL_INTENTS = (INTENTS - MUTATING_INTENTS).freeze

  def self.valid?(intent)
    intent.to_s.in?(INTENTS)
  end
end
