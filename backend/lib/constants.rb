module Constants
  module Automation
    PAUSED = "automation_paused"
    PAUSED_AT = "automation_paused_at"
    RESUMED_AT = "automation_resumed_at"
    EPOCH = "automation_epoch"
  end

  module Catalogue
    DEVICE_RECALL = /\b(?:what was my device|my device model|device model.*(?:ki|bolchilam))\b/i
    MAXIMUM_EVIDENCE_LINES = 4
    MAXIMUM_FACT_LENGTH = 600
    KNOWLEDGE_PROFILES = {
      "electronics" => { category: /electronic|tech|gadget|charger|earbud|watch/i, topics: %w[compatibility warranty package] },
      "fragrance" => { category: /perfume|fragrance|attar/i, topics: %w[scent longevity] },
      "apparel" => { category: /apparel|clothing|fashion|shirt|dress/i, topics: %w[material care] },
      "food" => { category: /food|bakery|cake|snack/i, topics: %w[ingredients allergens] }
    }.freeze
    QUESTION_TOPICS = {
      battery: { question: /\bbattery|\bhours?\b|ghonta|khon chole|দিন চলে/i, evidence: /battery|playback|hours?|mah|CR2032|months?/i },
      noise: { question: /\b(?:anc|enc|noise|call quality|microphone)\b/i, evidence: /\b(?:anc|enc|noise|microphone|call)\b/i },
      cable: { question: /\bcable\b/i, evidence: /\bcable\b/i },
      charging: { question: /\b(?:watts?|charge|charging speed|fast charging)\b/i, evidence: /speed|protocol|watt|depends? on|charging/i },
      warranty: { question: /\b(?:warranty|guarantee)\b/i, evidence: /\b(?:warranty|guarantee)\b/i },
      authenticity: { question: /\b(?:genuine|authentic|original Apple)\b/i, evidence: /\b(?:genuine|authentic|original Apple)\b/i },
      compatibility: { question: /compatib|\b(?:safe|fit|Android|iPhone|iOS|cholbe|work with)\b/i, evidence: /compatib|Android|iOS|iPhone|Samsung|protocol|physical fit/i },
      package: { question: /included|include|package|\b(?:straps?|koyta|inside|vitore|keychain|sathe|thakbe)\b/i, evidence: /included|include|package|straps?|keychain|contents|accessor/i },
      connectivity: { question: /\b(?:sim|bluetooth|phone|independent|calling|call)\b/i, evidence: /Bluetooth|SIM|call|connected|phone/i },
      tracking: { question: /\b(?:gps|live|tracker|pet|car|ecosystem|network|simultaneous|pair)\b/i, evidence: /GPS|real.time|network|ecosystem|one .*time|guaranteed|participating|SIM/i },
      waterproof: { question: /waterproof|\bswim/i, evidence: /waterproof|swim|water.resistan/i },
      medical: { question: /medical|diagnos|heart disease|heart condition/i, evidence: /medical|diagnos|wellness|health/i },
      designs: { question: /\b(?:designs?|colou?rs?)\b/i, evidence: /design|colou?r/i },
      scent: { question: /\b(?:scent|notes|smell|ghran)\b/i, evidence: /scent|notes|smell|floral|woody|oud|citrus/i },
      longevity: { question: /\b(?:longevity|lasting|lasts|lasting time)\b/i, evidence: /longevity|lasting|lasts|hours?/i },
      material: { question: /\b(?:material|fabric|cotton|kapor)\b/i, evidence: /material|fabric|cotton|polyester|silk/i },
      care: { question: /\b(?:wash|washing|care instructions)\b/i, evidence: /wash|care|dry.clean/i },
      ingredients: { question: /\b(?:ingredients|upokoron)\b/i, evidence: /ingredients|contains|made with/i },
      allergens: { question: /\b(?:allergens?|allergy|nuts?|gluten)\b/i, evidence: /allergens?|allergy|nuts?|gluten|cross.contamin/i }
    }.freeze
    ACCESSORY_WORDS = /\b(?:case|cover|accessor(?:y|ies)|protector)\b/i
    PRODUCT_REFERENCE = /\b(?:this|that|it|its|these|those|ei|etate|eta|etar|eita|oita|oi|first|second|third|previous|ager|prothom|ditiyo)\b/i
    OPTION_POSITIONS = { "first" => 0, "prothom" => 0, "second" => 1, "ditiyo" => 1, "third" => 2 }.freeze
    PURCHASE_REFERENCE_ACCEPTANCE = /\A(?:(?:eta|eita|etai|eitai|ei|ai|oita|oitai)(?:\s+product)?(?:\s+tai?)?(?:\s+i)?\s+(?:nibo|nite chai)|(?:i\s+)?(?:want|will take|would like)\s+(?:this|that)(?:\s+(?:one|product))?|(?:this|that)(?:\s+one)?\s+please)\z/i
    PURCHASE_ACKNOWLEDGEMENT = /\A(?:g|ji|jee|yes|yeah|ha|haa|hya|হ্যাঁ|জি)\z/i
    CATEGORY_PURCHASE_SUFFIX = /\s+(?:ta|ti)(?:\s+(?:nibo|nite chai|please))?\z/i
    PURCHASE_OFFER_QUESTION = /\b(?:nite chan|niben|order korte chan|would you like to (?:buy|order|take)|do you want (?:this|that))\b|নিতে চান|নেবেন|অর্ডার করতে চান/i
    MINIMUM_CATEGORY_TYPO_LENGTH = 5
    COMPATIBILITY_ATTRIBUTE_KEYS = %w[compatibility connector connectors protocol protocols].freeze
  end

  module Knowledge
    QUESTION_WORDS = %w[what are is the a an do does you your our please tell me about how much can i we have].freeze
  end

  module PhotoRecognition
    CAPTION_WINDOW = 3.seconds
    PHOTO_REFERENCE = /\b(?:this|that|photo|picture|image|eta|eita)\b|এইটা|এইটার|এটা|ছবি/i
    MAX_CUSTOMER_IMAGES = 3
    MAX_PRODUCTS = 20
    MAX_REFERENCE_IMAGES = 24
    REFERENCES_PER_PRODUCT = 2
    MAX_IMAGE_BYTES = 512.kilobytes
    MAX_DOWNLOAD_BYTES = 8.megabytes
    MAX_IMAGE_PIXELS = 25_000_000
    MAX_IMAGE_DIMENSION = 16_384
    ENCODING_OPTIONS = [ [ 1280, 85 ], [ 960, 75 ], [ 640, 65 ] ].map(&:freeze).freeze
    SUGGESTION_LIFETIME = 10.minutes
    NAMED_ORDER_REFERENCE = /\border\b|অর্ডার/i
    PHOTO_ACCEPTANCE = /\A(?:yes(?:,? (?:this one|that one|please))?|this one|that(?:'s| is) the one|ji|jee|ha|haa|hya|(?:ha |ji )?(?:eta|eita)(?:i| nibo| chai)?|হ্যাঁ|হ্যা|জি|এটাই|এটা (?:নিবো|নেব))[.! ]*\z/i
    PHOTO_REJECTION = /\A(?:no(?:,? (?:not this|not this one|thanks))?|not this(?: one)?|na|nah|eta na|eita na|না|এটা না)[.! ]*\z/i
    ORDER_REQUEST = /\b(?:want|need|take|give|send|buy|order|nibo|chai|den|dao|din|add|include)\b|নিবো|নেব|চাই|দেন|যোগ করুন/i
    ORDER_NEGATION = /\b(?:not|no|don t|do not|later|pore|nibo na|chai na|or|ba|compare|instead)\b|না|পরে|অথবা|নাকি|বদলে/i
    CART_ADDITION = /\b(?:add|include)\b|যোগ করুন/i
    UNSAFE_CAPTION_QUANTITY = /(?:\A|\s)-\s*\d|\d+\.\d+\s*(?:pcs?|pieces?|bottles?|units?|টা|টি|পিস|বোতল)/i
    CAPTION_WORDS = { "একটা" => "1 pcs", "একটি" => "1 pcs", "দুইটা" => "2 pcs", "দুইটি" => "2 pcs",
      "দুটো" => "2 pcs", "তিনটা" => "3 pcs", "তিনটি" => "3 pcs", "চারটা" => "4 pcs",
      "পাঁচটা" => "5 pcs", "বোতল" => "bottles", "পিস" => "pcs", "মিলি" => "ml" }.freeze
    MIN_CONFIDENCE = 0.85
    PROCESSING_LEASE = 5.minutes
    IMAGE_TIMEOUT_SECONDS = 5
    REFERENCE_BUDGET_SECONDS = 45
  end

  module ProductImages
    MAX_IMAGES = 8
    MAX_URL_LENGTH = 2048
    PUBLIC_HOST = /\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,63}\z/i
    LOCAL_SUFFIXES = %w[.localhost .local .internal].freeze
  end

  module Conversation
    PURCHASE_DECLINED = /\b(?:nibo na|nite chai na|kinbo na|chai na|do not (?:want|buy|order|take)|don t (?:want|buy|order|take)|not buying|not ordering|will not (?:buy|take|order))\b|নিবো না|নেব না|কিনব না/i
    CHECKOUT_PROGRESS_OUTCOMES = %i[product_selected variant_selected quantity_collected multiple_details_collected cart_updated].freeze
    REPLY_QUESTION_CUES = {
      "customer_name" => /\b(?:name|naam|nam)\b|নাম/i,
      "phone" => /\b(?:phone|mobile|number|contact)\b|ফোন|মোবাইল|নম্বর/i,
      "address" => /\b(?:address|location|thikana|where)\b|ঠিকানা|কোথায়/i,
      "quantity" => /\b(?:quantity|many|koyta|bottles?|pieces?|units?)\b|কয়টা|কতটি|পরিমাণ/i,
      "variant" => /\b(?:size|variant|ml|colour|color|design|option)\b|সাইজ|রং|ডিজাইন/i,
      "product" => /\b(?:product|perfume|fragrance|one|which|choose|niben|nite|order|buy|take|proceed|go ahead)\b|পণ্য|কোন|নিবেন|নিতে|অর্ডার/i,
      "confirmation" => /\b(?:confirm|correct|proceed|place|thik|final)\b|নিশ্চিত|ঠিক|কনফার্ম/i
    }.freeze
    REPLY_LIMITATION = /\b(?:not|cannot|can't|unverified|unknown|depends?|require|only|one .*time|confirm whether|not verified|na)\b|যাচাই|নিশ্চিত নয়|নির্ভর|নেই|নয়/i
    QUESTION_HISTORY_LIMIT = 5
    QUESTION_FIELDS = {
      "collecting_product" => [ "product", "product_reference" ],
      "collecting_variant" => [ "variant", "variant_reference" ],
      "collecting_quantity" => [ "quantity", "positive_integer" ],
      "collecting_name" => [ "customer_name", "name" ],
      "collecting_phone" => [ "phone", "phone_number" ],
      "collecting_address" => [ "address", "address" ],
      "awaiting_confirmation" => [ "confirmation", "explicit_confirmation" ]
    }.freeze
    HUMAN_REQUEST = /\A(?:human(?: agent)?|real person|real seller|live agent|customer representative)[!.? ]*\z|\b(?:need|want|prefer|talk|speak|connect)\b.*\b(?:human(?: agent)?|real person|real seller|live agent|customer representative)\b|\b(?:talk|speak|connect|kotha)\b.*\b(?:someone|person|seller|owner|manager|agent|manush)\b|\b(?:seller|owner|manager|manush)\b.*\b(?:talk|speak|connect|kotha)\b|মানুষের সাথে|সেলারের সাথে/i
    LANGUAGE_REQUEST = /\b(?:continue|speak|reply|answer|bolen|bolun)\b.*\b(?:english|banglish|bangla|bengali)\b|\b(?:english|banglish|bangla|bengali)\s+(?:e|te|please|bolen)\b/i
    BANGLISH_CUES = /\b(?:koto|koyta|ache|ase|achen|kemon|korbo|koren|korun|dekhan|pabo|lagbe|bolen|amar|apni|sathe|thakbe|nibo|chai|duita|ekta|moddhe|pore|chole|hobe)\b/i
    PRODUCT_FACT_QUESTION = /\A(?:please\s+)?(?:what|which|how|does|do|is|will|can|tell|describe|compare)\b|\b(?:what is|how much|difference|battery|warranty|compatib\w*|included|cable|keychain|capacity|support|fit|koto|koyta|koy|ache|ase|hobe|cholbe|chole|bolen|thakbe)\b|কত|কোন|আছে|বলেন/i
    EXPLICIT_PURCHASE_ACTION = /\b(?:buy|take|send|give|add|remove|change|update|nibo|den|dao)\b|নিবো|দেন/i
    EXPLICIT_QUANTITY_UNITS = /\b(?:\d+|one|two|three|ekta|duita)\s*(?:pieces?|pcs?|bottles?|units?|ta)\b/i
    BROWSING_ONLY = /\b(?:just browsing|only browsing|browsing only|only wanted information|just looking|do not (?:place|create|confirm)|not ordering|not an order|order (?:ekhon na|na)|sudhu (?:dekhchi|information)|pore decide|pause rakhen|pore kinbo|buy later)\b/i
    LARGER_OPTION_QUESTION = /\b(?:bigger|larger|next size|aro boro|boro size)\b|আরও বড়|বড় সাইজ/i
    CART_SHORT_CORRECTION = /\Aactually\s+(?:\d+|one|two|three|ekta|duita)\s+([a-z]+)\z/i
    PRODUCT_CONTENTS_QUESTION = /\b(?:what is included|what does it include|etar vitore ki ache|er moddhe ki ache|what is inside)\b/i
    ENGINE_VERSION = "2026.10.7"
    CART_TOTAL_REQUEST = /\b(?:total|subtotal|mot dam|shob mile)\b|মোট.*(?:দাম|কত)/i
    CART_CONTENTS_REQUEST = /\A(?:ki ki ache ekhon|order e ki ki ache|ekhon cart e ki ki ache|what is in (?:my |the )?cart(?: now)?)[?.! ]*\z/i
    CART_ITEM_UPDATE = /\A(?:actually\s+)?(?:make|change|update)\b|\b(?:koren|korun|kore den)\b/i
    CART_MUTATION_CUE = /\b(?:add|remove|delete|drop|change|update|den|nibo|give|take)\b/i
    CART_NAMED_QUANTITY = /\b(?:one|two|three|ekta|duita|\d+)\s+(?:koren|korun|করেন|করুন)\z/i
    CART_DISCARD_UNKNOWN = /\b(?:bad|remove|ignore|drop)\b.*\b(?:shudhu|only)\b/i
    PRODUCT_INQUIRY_OUTCOMES = %i[price_inquiry stock_inquiry product_details_requested product_variants_requested].freeze
    INQUIRY_VARIANT_FOLLOW_UP = /\b\d+(?:\.\d+)?\s*ml\b|\b(?:bigger|larger|largest|smallest|boro|choto|medium|last one)\b/i
    INQUIRY_QUESTION = /[?？]|\b(?:ache|available|price|cost|koto|options?|sizes?)\b/i
    INQUIRY_REFERENCE = /\b(?:this|that|it|eta|etar|eita|oita|oi)\b|এটা|ওটা/i
    INQUIRY_RESET_OUTCOMES = %i[product_list_requested product_comparison_requested product_recommendation_requested
      recommendations_rejected product_selected variant_selected multiple_details_collected cart_updated].freeze
    CHECKOUT_EDIT_FIELDS = {
      "phone" => /\A(?:change|update|edit)\s+(?:my\s+)?phone(?:\s+number)?[?.! ]*\z|\Aphone(?:\s+number)?\s+change\s+korbo[?.! ]*\z/i,
      "address" => /\A(?:change|update|edit)\s+(?:my\s+|the\s+)?address[?.! ]*\z|\Aaddress\s+change\s+korbo[?.! ]*\z/i,
      "customer_name" => /\A(?:change|update|edit)\s+(?:my\s+)?name[?.! ]*\z|\A(?:name|naam)\s+change\s+korbo[?.! ]*\z/i
    }.freeze
    QUANTITY_CORRECTION = /\A(?:actually[\s,]*)?(?:(?:change|update)\s+(?:the\s+)?quantity\s+(?:to\s+)?[0-9০-৯]+|(?:(?:পরিমাণ|quantity)\s+)?(?:[0-9০-৯]+\s*(?:টা|ta|bottles?)?|one|two|three|ekta|duita|একটা|দুইটা)\s+(?:ta\s+)?(?:koren|korun|kore den|করেন|করুন|hobe|হবে))[?.! ]*\z/i
    GREETING_ONLY = /\A(?:hi|hello|hey|assalamu?\s*alaikum|assalamu?laikum|assalamulaikum|salam|হ্যালো|আসসালামু আলাইকুম)(?:\s+(?:there|bhai|apu|sir|madam))?[!. ]*\z/i
    THANKS_ONLY = /\A(?:thanks(?: a lot)?|thank you(?: very much)?|dhonnobad|onek dhonnobad|ধন্যবাদ|অনেক ধন্যবাদ)[!. ]*\z/i
    CUSTOMER_NAME_PREFIX = /\A(?:(?:hi|hello|hey|হ্যালো)(?:\s+there)?[,!. ]+)?(?:my name is|i am|i'm|amar naam|amar nam|name|naam|আমার নাম)\s*[:=-]?\s*(.+?)[.! ]*\z/i
    NON_NAME_CONVERSATION = /\b(?:i|we|you|my|your|have|need|want|trying|loading|question|ordered|when|why|how|please|hello|hi)\b|আমার|আপনার|চাই|কেন|কিভাবে/i
    SUPPORT_ACCESS_REQUEST = /\b(?:password|login|log in|sign in|account access|reset account|two.factor|2fa)\b|পাসওয়ার্ড|লগইন/i
    SUPPORT_TECHNICAL_REQUEST = /\b(?:cart|checkout|check out|search|website|site)\b.*\b(?:not loading|not updating|won'?t|isn'?t|can't|cannot|not working|error|broken)\b|\b(?:can't|cannot)\b.*\b(?:checkout|check out|log in)\b/i
    CONVERSATION_REPAIR_THRESHOLD = 3
    SUPPORT_REPAIR_THRESHOLD = 2
    SUPPORT_FAILURE_FOLLOW_UP = /\b(?:still not working|not working|did not work|didn't work|same problem)\b|কাজ করছে না|ekhono kaj|kaj korche na/i
    REPAIR_REFERENCE = /\b(?:that|it|same|again|meant)\b|ওটা|সেটা|oita|sheta/i
    REPAIR_TOPICS = {
      delivery: /\b(?:delivery|shipping|parcel|courier)\b|ডেলিভারি|deli?very/i,
      payment: /\b(?:payment|pay|cod|card)\b|পেমেন্ট/i,
      order: /\b(?:order|refund|return)\b|অর্ডার|ফেরত/i
    }.freeze
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
      "ekta" => 1, "ektai" => 1, "akta" => 1, "duita" => 2, "duta" => 2, "tinta" => 3, "charta" => 4
    }.freeze
    NON_NAME_REPLIES = %w[
      yes yeah yep okay ok sure confirm confirmed fine good works perfect thanks thankyou
      ha haa ji jii thik thikache accha acha
    ].freeze
    EXPLICIT_CONFIRMATION = /\A(?:confirm(?:ed)?|yes|y|confirm (?:my |the )?order|order confirm(?: koro| korun)?|হ্যাঁ|নিশ্চিত করুন)[.! ]*\z/i
    EXPLICIT_CANCELLATION = /\A(?:cancel(?:led)?|stop|(?:please )?cancel (?:(?:my|the|this|entire)\s+)*(?:test\s+)?order(?: please)?|(?:ei |puro )?(?:test )?order(?: ta)? (?:cancel|bad|batil)(?: koro| korun| koren| den)?|batil koren|বাতিল করুন|অর্ডার(?:টা)? বাতিল করুন)[.! ]*\z/i
    NON_NAME_SENTENCE = /(?:\b(?:password|forgot|cannot|can't|don't|do not|confirm|cancel|delivery|refund|payment)\b|পাসওয়ার্ড|বাতিল|পরে)/i
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
      cart_needs_details cart_inventory_unavailable cart_locked unsupported_support_requested
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
    MESSENGER_PROCESSABLE_EVENT_TYPES = %w[customer_text customer_image].freeze
    GRAPH_API_VERSION = "v21.0"
    WHATSAPP_MESSAGES_URL = "https://graph.facebook.com/%{version}/%{phone_number_id}/messages"
    RETRYABLE_STATUS_CODES = [ 408, 429 ].freeze
    WHATSAPP_EVENT_TYPES = %w[customer_text attachment delivery_status unknown].freeze
    WEBHOOK_EVENT_STATUSES = %w[received processing processed ignored failed].freeze
    DELIVERY_STATUSES = %w[pending retrying sent delivered read failed skipped].freeze
  end
end
