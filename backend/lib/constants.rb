module Constants
  module Conversation
    ENGINE_VERSION = "2026.10.5"
    BANGLISH_WORDS = {
      "oitai" => "oita", "eitar" => "etar", "eigula" => "egula", "eigulo" => "egula",
      "agerta" => "ager ta", "agereta" => "ager ta", "kotoo" => "koto",
      "kotho" => "koto", "daam" => "dam", "damm" => "dam",
      "niboo" => "nibo", "nimu" => "nibo", "diben" => "den"
    }.freeze
    INITIAL_CATALOG_LIMIT = 6
    NUMBER_WORDS = {
      "one" => 1, "two" => 2, "three" => 3, "four" => 4, "five" => 5,
      "six" => 6, "seven" => 7, "eight" => 8, "nine" => 9, "ten" => 10,
      "ekta" => 1, "akta" => 1, "duita" => 2, "duta" => 2, "tinta" => 3, "charta" => 4
    }.freeze
    NON_NAME_REPLIES = %w[
      yes yeah yep okay ok sure confirm confirmed fine good works perfect thanks thankyou
      ha haa ji jii thik thikache accha acha
    ].freeze
    AI_OUTCOMES = {
      "greeting" => :greeting, "thanks" => :thanks, "help" => :help, "wellbeing" => :wellbeing,
      "goodbye" => :goodbye, "bot_identity" => :bot_identity, "language_preference" => :language_preference,
      "complaint" => :complaint, "human_agent" => :human_agent, "list_products" => :product_list_requested,
      "product_search" => :product_list_requested, "product_details" => :product_details_requested,
      "product_price" => :price_inquiry, "product_availability" => :stock_inquiry,
      "product_recommendation" => :product_recommendation_requested, "compare_products" => :product_comparison_requested,
      "product_variants" => :product_variants_requested, "product_images" => :product_images_requested,
      "out_of_stock" => :alternative_product_requested, "alternative_product" => :alternative_product_requested,
      "gift_recommendation" => :product_recommendation_requested, "refine_recommendation" => :product_recommendation_requested,
      "reject_recommendations" => :recommendations_rejected, "shortlist_add" => :shortlist_updated,
      "shortlist_remove" => :shortlist_updated, "shortlist_show" => :shortlist_requested,
      "resume_order" => :resume_order_requested, "order_history" => :order_history_requested,
      "payment_methods" => :payment_methods_requested, "cash_on_delivery" => :cash_on_delivery_requested,
      "delivery_charge" => :delivery_charge_requested, "delivery_area" => :delivery_area_requested,
      "delivery_time" => :delivery_time_requested, "return_request" => :return_requested,
      "replacement_request" => :replacement_requested, "refund_request" => :refund_requested,
      "order_status" => :order_details_requested, "defer_confirmation" => :confirmation_deferred
    }.freeze
    FOCUSED_OUTCOMES = %i[
      cart_needs_details cart_inventory_unavailable cart_locked
      product_recommendation_requested recommendation_choice_reminder product_variants_requested product_ambiguous
      variant_not_found clarification_needed product_weather_requested first_time_scent_guidance
    ].freeze
    INTERRUPTING_OUTCOMES = %i[
      price_inquiry stock_inquiry product_details_requested product_recommendation_requested
      product_comparison_requested product_variants_requested product_images_requested
      payment_methods_requested cash_on_delivery_requested delivery_charge_requested
      delivery_area_requested delivery_time_requested product_weather_requested
      alternative_product_requested discount_requested authenticity_requested trust_information_requested
      trial_requested delivery_price_objection price_objection return_policy_requested return_requested
      replacement_requested refund_requested
    ].freeze
    GUIDED_SALES_STAGES = %w[discover compare select configure checkout confirm complete].freeze
    GUIDED_SALES_OUTCOME_STAGES = {
      product_recommendation_requested: "discover", alternative_product_requested: "discover",
      product_comparison_requested: "compare", recommendations_rejected: "discover",
      shortlist_updated: "compare", product_selected: "select", variant_selected: "configure",
      quantity_collected: "checkout", address_collected: "confirm", confirmed: "complete",
      order_paused: "discover"
    }.freeze
  end

  module Fragrance
    SCENT_FAMILIES = {
      "fresh" => %w[fresh clean citrus aquatic marine airy halka],
      "sweet" => %w[sweet vanilla gourmand caramel chocolate mishti],
      "fruity" => %w[fruity fruit berry berries cherry plum],
      "floral" => %w[floral flower rose jasmine],
      "woody" => %w[woody wood cedar sandalwood],
      "oud" => %w[oud oudy oudi oody oddy ody agarwood arabian oriental middle-eastern],
      "spicy" => %w[spicy spice warm],
      "tobacco" => %w[tobacco smoky smoke]
    }.freeze
    OCCASIONS = {
      "office" => %w[office work professional meeting], "daily" => %w[daily everyday casual regular],
      "date" => %w[date romantic intimate], "party" => %w[party event celebration gathering],
      "formal" => %w[formal wedding special], "gift" => %w[gift birthday anniversary eid]
    }.freeze
  end

  module Intents
    GROUPS = {
      social: %w[greeting wellbeing thanks goodbye help bot_identity language_preference unclear complaint human_agent],
      products: %w[
        list_products product_search product_details product_price product_availability product_recommendation
        compare_products product_variants product_images out_of_stock alternative_product gift_recommendation
        refine_recommendation reject_recommendations shortlist_add shortlist_remove shortlist_show closest_alternative
      ],
      ordering: %w[
        new_order repeat_order select_product select_quantity provide_name provide_phone provide_address
        review_order confirm_order cancel_order resume_order defer_confirmation browse_products go_back
      ],
      updates: %w[
        change_product change_quantity change_name change_phone change_address order_details order_history
        change_confirmed_order
      ],
      payment_and_delivery: %w[payment_methods cash_on_delivery delivery_charge delivery_area delivery_time order_status],
      after_sales: %w[return_request replacement_request refund_request]
    }.freeze
    ALL = GROUPS.values.flatten.freeze
    MUTATING = %w[
      new_order repeat_order select_product select_quantity provide_name provide_phone provide_address
      confirm_order cancel_order change_product change_quantity change_name change_phone change_address
      change_confirmed_order
    ].freeze
    INFORMATIONAL = (ALL - MUTATING).freeze
  end

  module Meta
    GRAPH_API_VERSION = "v21.0"
    WHATSAPP_MESSAGES_URL = "https://graph.facebook.com/%{version}/%{phone_number_id}/messages"
    RETRYABLE_STATUS_CODES = [ 408, 429 ].freeze
    WHATSAPP_EVENT_TYPES = %w[customer_text attachment delivery_status unknown].freeze
    WEBHOOK_EVENT_STATUSES = %w[received processing processed ignored failed].freeze
    DELIVERY_STATUSES = %w[pending retrying sent delivered read failed skipped].freeze
  end
end
