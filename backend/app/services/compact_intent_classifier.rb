class CompactIntentClassifier
  # Character n-gram scores are intentionally conservative and are not model
  # probabilities. Held-out multilingual phrases generally match at 0.45–0.75.
  MINIMUM_CONFIDENCE = 0.44
  MAXIMUM_EXAMPLES_PER_INTENT = 40
  DATASET_PATH = Rails.root.join("config/intent_examples.yml")
  PREFIXES = [ "please ", "bhai ", "apni ", "ektu " ].freeze
  SUFFIXES = [ "?", " please", " bhai" ].freeze
  SEEDS = {
    "greeting" => [ "hi", "hello", "hey", "assalamualaikum", "assalamulaikum", "salam", "হ্যালো", "আসসালামু আলাইকুম" ],
    "wellbeing" => [ "how are you", "kemon achen", "ki obostha", "আপনি কেমন আছেন", "কেমন আছেন" ],
    "thanks" => [ "thanks", "thank you", "dhonnobad", "onek dhonnobad", "ধন্যবাদ", "অনেক ধন্যবাদ" ],
    "goodbye" => [ "bye", "goodbye", "see you", "allah hafez", "আল্লাহ হাফেজ", "বিদায়" ],
    "help" => [ "help", "help me", "ki korte paren", "how can you help", "সাহায্য করুন", "কি করতে পারেন" ],
    "list_products" => [ "show all", "show all products", "show me products", "available products", "product gula dekhan", "shob product dekhao", "shobgula product dekhte chai", "সব প্রোডাক্ট দেখান", "কি কি প্রোডাক্ট আছে" ],
    "product_price" => [ "price koto", "how much", "what is the price", "dam koto", "etar dam ta bolben", "দাম কত", "প্রাইস কত", "এটার দাম বলবেন" ],
    "product_availability" => [ "in stock", "available ache", "do you have this", "stock ache", "stock e pawa jabe", "স্টক আছে", "এটা পাওয়া যাবে" ],
    "product_variants" => [ "size options", "what sizes", "available size gulo ki", "kon size ache", "50 ml ache", "100ml nai", "কি কি সাইজ আছে", "৫০ এমএল আছে" ],
    "product_details" => [ "product details", "notes ki", "describe this", "details bolen", "ei perfume somporke bolen", "নোটস কি", "বিস্তারিত বলুন" ],
    "product_recommendation" => [ "suggest something", "recommend a perfume", "amar jonno kichu suggest koren", "ki nibo", "কিছু সাজেস্ট করুন", "কোনটা নেব" ],
    "compare_products" => [ "compare these", "difference ki", "which is better", "konta better", "duitar moddhe konta valo", "পার্থক্য কি", "কোনটা ভালো" ],
    "new_order" => [ "new order", "start new order", "notun order", "arekta order korte chai", "abar order korbo", "নতুন অর্ডার", "আবার অর্ডার করব" ],
    "order_details" => [ "my order details", "show my order", "amar order ki", "order summary", "আমার অর্ডার দেখান", "অর্ডার ডিটেইলস" ],
    "confirm_order" => [ "confirm order", "order confirm", "yes confirm", "confirm koren", "অর্ডার কনফার্ম", "কনফার্ম করুন" ],
    "cancel_order" => [ "cancel order", "stop order", "order cancel", "order ta bad den", "batil koren", "অর্ডারটা বাদ দেন", "অর্ডার বাতিল", "ক্যানসেল করুন" ],
    "delivery_charge" => [ "delivery charge koto", "shipping fee", "delivery cost", "dhaka delivery charge", "ডেলিভারি চার্জ কত", "শিপিং খরচ" ],
    "delivery_time" => [ "delivery time", "when will it arrive", "kobe pabo", "koto din lagbe", "কবে পাব", "কতদিন লাগবে" ],
    "delivery_area" => [ "deliver here", "delivery area", "dhakar baire delivery", "amar elakay delivery", "amar location e pathaben", "এখানে ডেলিভারি হবে", "ডেলিভারি এরিয়া" ],
    "payment_methods" => [ "payment method", "how can i pay", "bkash ache", "card diye pay kora jabe", "payment kivabe", "পেমেন্ট কিভাবে", "বিকাশ আছে" ],
    "cash_on_delivery" => [ "cash on delivery", "cod ache", "delivery te payment", "product pawar por taka dibo", "ক্যাশ অন ডেলিভারি", "হাতে টাকা দেব" ],
    "human_agent" => [ "talk to seller", "human agent", "owner er sathe kotha", "manusher sathe kotha bolbo", "সেলারের সাথে কথা", "মানুষের সাথে কথা বলব" ],
    "language_preference" => [ "speak bangla", "reply in english", "banglish e bolen", "banglate uttor diben", "বাংলায় বলুন", "বাংলাতে উত্তর দিবেন", "ইংরেজিতে বলুন" ],
    "bot_identity" => [ "are you a bot", "who are you", "kar sathe kotha bolchi", "apni ke", "আপনি কে", "এটা কি বট" ],
    "complaint" => [ "i have a complaint", "this is frustrating", "service valo na", "problem hoise", "অভিযোগ আছে", "সমস্যা হয়েছে" ],
    "product_images" => [ "show picture", "product photo", "chobi dekhan", "picture ache", "ছবি দেখান", "প্রোডাক্টের ছবি" ],
    "alternative_product" => [ "show another option", "something similar", "onno kichu dekhan", "alternative ache", "অন্য কিছু দেখান", "বিকল্প আছে" ],
    "gift_recommendation" => [ "suggest a gift", "birthday gift", "gift er jonno chai", "upohar dibo", "গিফটের জন্য", "উপহার দিতে চাই" ],
    "reject_recommendations" => [ "i do not like these", "none of these", "egula pochondo na", "onno rokom chai", "এগুলো পছন্দ না", "অন্য রকম চাই" ],
    "shortlist_show" => [ "show my shortlist", "saved options", "shortlist ta dekhan", "ki ki save korsi", "শর্টলিস্ট দেখান", "সেভ করা অপশন" ],
    "resume_order" => [ "continue order", "resume my order", "order ta continue kori", "jekhane chilam", "অর্ডার চালিয়ে যাই", "আগের জায়গা থেকে" ],
    "defer_confirmation" => [ "confirm later", "i will decide later", "pore confirm korbo", "ekhon na", "পরে কনফার্ম করব", "এখন না" ],
    "order_history" => [ "previous orders", "what did i buy", "ager order dekhan", "purono order", "আগের অর্ডার দেখান", "কি কিনেছিলাম" ],
    "order_status" => [ "where is my order", "order status", "amar order koi", "order kobe pabo", "আমার অর্ডার কোথায়", "অর্ডারের অবস্থা" ],
    "return_request" => [ "return product", "want to return", "ferot dite chai", "return korbo", "ফেরত দিতে চাই", "রিটার্ন করব" ],
    "replacement_request" => [ "replace product", "need replacement", "bodle dite chai", "change kore den", "বদলে দিতে চাই", "রিপ্লেসমেন্ট চাই" ],
    "refund_request" => [ "need refund", "money back", "taka ferot chai", "refund chai", "টাকা ফেরত চাই", "রিফান্ড চাই" ]
  }.freeze

  def self.dataset_seeds
    @dataset_seeds ||= begin
      data = YAML.safe_load_file(DATASET_PATH, aliases: false)
      data.fetch("intents").transform_values { |examples| Array(examples).map(&:to_s) }
    end
  end

  def self.seeds
    SEEDS.merge(dataset_seeds) do |_intent, built_in, configured|
      (built_in + configured).uniq
    end
  end

  Result = Data.define(:interpretation, :score, :runner_up_score, :source, :candidate_intent, :runner_up_intent)

  def self.examples
    @examples ||= seeds.transform_values do |seeds|
      variants = seeds.dup
      PREFIXES.each { |prefix| seeds.each { |seed| variants << "#{prefix}#{seed}" } }
      SUFFIXES.each { |suffix| seeds.each { |seed| variants << "#{seed}#{suffix}" } }
      variants.map(&:strip).uniq.first(MAXIMUM_EXAMPLES_PER_INTENT)
    end
  end

  def initialize(message:, pending_order:)
    @message = message
    @pending_order = pending_order
  end

  def classify
    return empty_result if checkout_value?

    ranked = self.class.examples.map do |intent, examples|
      [ intent, examples.map { |example| similarity(normalized, normalize(example)) }.max ]
    end.sort_by { |_intent, score| -score }
    intent, score = ranked.first
    runner_up_intent, runner_up = ranked.second
    runner_up = runner_up.to_f
    adjusted = [ score + context_bonus(intent), 1.0 ].min
    return empty_result(score: adjusted, runner_up_score: runner_up,
      candidate_intent: intent, runner_up_intent: runner_up_intent) if yield_to_checkout?(intent)
    if adjusted < MINIMUM_CONFIDENCE || adjusted - runner_up < 0.04
      return empty_result(score: adjusted, runner_up_score: runner_up,
        candidate_intent: intent, runner_up_intent: runner_up_intent)
    end

    Result.new(interpretation: AiIntentClassifier::Result.new(
      intent: intent, secondary_intents: [], confidence: adjusted, entities: {}.with_indifferent_access,
      language: detected_language, sentiment: "neutral", needs_clarification: false, possible_intents: []
    ), score: adjusted, runner_up_score: runner_up, source: "local",
      candidate_intent: intent, runner_up_intent: runner_up_intent)
  end

  private

  attr_reader :message, :pending_order
  def normalized = @normalized ||= normalize(message.content)
  def empty_result(score: 0.0, runner_up_score: 0.0, candidate_intent: nil, runner_up_intent: nil) = Result.new(
    interpretation: nil, score: score, runner_up_score: runner_up_score, source: "local",
    candidate_intent: candidate_intent, runner_up_intent: runner_up_intent
  )

  def checkout_value?
    return true if pending_order&.collecting_phone? && normalized.match?(/\A\+?\d[\d ]{7,14}\z/)
    if pending_order&.status.in?(%w[collecting_variant collecting_quantity collecting_name collecting_phone collecting_address])
      return true if normalized.match?(/\b\d+\s*(?:ml|gm|kg|pieces?|pcs?)\b/)
      return true if normalized.match?(/\b(bigger|larger|next size|aro boro|boro size)\b|আরও বড়|বড় সাইজ/)
    end

    false
  end

  def yield_to_checkout?(intent)
    return true if intent.in?(%w[confirm_order cancel_order]) && !pending_order&.awaiting_confirmation?
    return false unless pending_order&.collecting_address?

    # A plain address such as "Badda, Dhaka" must be collected as the address,
    # not mistaken for a delivery-area or Dhaka delivery-charge question.
    !normalized.match?(/(?:\?|delivery|deliver|shipping|charge|koto|ki\b|how\b|can\b|হবে|কত|চার্জ)/i)
  end
  def normalize(value) = value.to_s.downcase.unicode_normalize(:nfkc).gsub(/[^\p{L}\p{N}]+/u, " ").squish
  def grams(value) = value.length < 3 ? [ value ] : value.chars.each_cons(3).map(&:join).uniq

  def similarity(left, right)
    return 1.0 if left == right
    left_grams, right_grams = grams(left), grams(right)
    dice = (2.0 * (left_grams & right_grams).size) / (left_grams.size + right_grams.size)
    left_words, right_words = left.split, right.split
    # A customer often wraps a short intent phrase in a longer sentence. Compare
    # against the shorter side so "please show me all available products" still
    # strongly matches "show products" without requiring the same word count.
    token = (left_words & right_words).size.to_f / [ [ left_words.size, right_words.size ].min, 1 ].max
    (dice * 0.45) + (token * 0.55)
  end

  def context_bonus(intent)
    expected = case pending_order&.status
    when "collecting_variant" then %w[product_variants product_price product_availability]
    when "collecting_quantity" then %w[product_price product_availability]
    when "awaiting_confirmation" then %w[confirm_order cancel_order order_details]
    else []
    end
    intent.in?(expected) ? 0.05 : 0.0
  end

  def detected_language
    return "bengali" if message.content.match?(/\p{Bengali}/)
    return "banglish" if normalized.match?(/\b(koto|ache|achen|kemon|korbo|koren|dekhan|pabo|lagbe|bolen|amar|apni)\b/)
    "english"
  end
end
