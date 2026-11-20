module ConversationJourneyAssertions
  def assert_conversation_journey(business:, steps:, customer: SecureRandom.uuid)
    classifier = Object.new
    classifier.define_singleton_method(:classify) { nil }
    assistant = Object.new
    assistant.define_singleton_method(:rewrite) { |fallback:| fallback }
    assistant.define_singleton_method(:telemetry) { {} }
    results = []
    with_journey_constructor(AiIntentClassifier, classifier) do
      with_journey_constructor(AiConversationAssistant, assistant) do
        steps.each_with_index do |step, index|
          captured = business.orders.count
          result = CustomerMessageRecorder.new(business: business, channel: "facebook",
            external_customer_id: customer, content: step.fetch(:say)).record
          label = "turn #{index + 1}: #{step.fetch(:say)}"
          step.fetch(:order, {}).each do |field, expected|
            actual = result.pending_order.reload.public_send(field)
            expected.nil? ? assert_nil(actual, "#{label} / #{field}") : assert_equal(expected, actual, "#{label} / #{field}")
          end
          Array(step[:includes]).each { |fact| assert_includes result.bot_reply&.content.to_s, fact, label }
          Array(step[:excludes]).each { |fact| refute_includes result.bot_reply&.content.to_s, fact, label }
          assert_equal captured, business.orders.count, "#{label} unexpectedly captured an order" unless step[:allows_capture]
          refute_predicate result.conversation.reload, :handed_over?, label unless step[:allows_handover]
          results << result
        end
      end
    end
    results
  end

  def with_journey_constructor(klass, instance)
    original = klass.method(:new)
    klass.define_singleton_method(:new) { |*_, **_| instance }
    yield
  ensure
    klass.define_singleton_method(:new, original)
  end
end
