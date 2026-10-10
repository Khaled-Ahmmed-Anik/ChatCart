class ConversationEvaluationSuite
  DATASET_PATH = Rails.root.join("config/conversation_evaluations.yml")
  SUPPORTED_LOCALES = %w[english bengali banglish].freeze

  Case = Data.define(:id, :message, :expected_intent, :locale, :pending_order_status, :tags)

  def self.load(path: DATASET_PATH)
    payload = YAML.safe_load_file(path, aliases: false)
    raise ArgumentError, "unsupported evaluation schema" unless payload["schema_version"] == 1

    cases = Array(payload["cases"]).map do |attributes|
      Case.new(
        id: attributes.fetch("id"),
        message: attributes.fetch("message"),
        expected_intent: attributes.fetch("expected_intent"),
        locale: attributes.fetch("locale"),
        pending_order_status: attributes["pending_order_status"] || "collecting_product",
        tags: Array(attributes["tags"])
      )
    end
    validate!(cases)
    cases
  end

  def self.validate!(cases)
    duplicate_ids = cases.group_by(&:id).select { |_id, entries| entries.many? }.keys
    raise ArgumentError, "duplicate evaluation ids: #{duplicate_ids.join(', ')}" if duplicate_ids.any?

    cases.each do |evaluation_case|
      raise ArgumentError, "blank evaluation message: #{evaluation_case.id}" if evaluation_case.message.blank?
      unless evaluation_case.expected_intent.in?(ConversationIntentRegistry.intents)
        raise ArgumentError, "unknown intent #{evaluation_case.expected_intent}: #{evaluation_case.id}"
      end
      unless evaluation_case.locale.in?(SUPPORTED_LOCALES)
        raise ArgumentError, "unknown locale #{evaluation_case.locale}: #{evaluation_case.id}"
      end
      unless evaluation_case.pending_order_status.in?(PendingOrder.statuses.keys)
        raise ArgumentError, "unknown order status #{evaluation_case.pending_order_status}: #{evaluation_case.id}"
      end
    end
  end

  private_class_method :validate!
end
