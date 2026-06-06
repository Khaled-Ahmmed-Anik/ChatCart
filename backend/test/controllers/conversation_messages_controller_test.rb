require "test_helper"

class ConversationMessagesControllerTest < ActionDispatch::IntegrationTest
  test "create records an incoming customer message for a new conversation" do
    assert_difference -> { Conversation.count }, 1 do
      assert_difference -> { Message.count }, 1 do
        assert_difference -> { PendingOrder.count }, 1 do
          post conversation_messages_url, params: {
            conversation_message: {
              channel: "facebook",
              external_customer_id: "fb-user-123",
              content: "Hi, I want a perfume"
            }
          }, as: :json
        end
      end
    end

    assert_response :created

    response_body = JSON.parse(response.body)
    conversation = Conversation.find(response_body.dig("conversation", "id"))
    message = conversation.messages.sole
    pending_order = conversation.pending_order

    assert_equal "facebook", response_body.dig("conversation", "channel")
    assert_equal "fb-user-123", response_body.dig("conversation", "external_customer_id")
    assert_equal "active", response_body.dig("conversation", "status")
    assert_equal conversation.last_message_at.iso8601, response_body.dig("conversation", "last_message_at")
    assert_equal message.id, response_body.dig("message", "id")
    assert_equal "customer", response_body.dig("message", "sender_type")
    assert_equal "Hi, I want a perfume", response_body.dig("message", "content")
    assert_equal pending_order.id, response_body.dig("pending_order", "id")
    assert_equal "collecting_product", response_body.dig("pending_order", "status")
    assert_equal false, response_body.dig("pending_order", "ready_for_confirmation")
  end

  test "create reuses existing conversation and pending order" do
    conversation = Conversation.create!(
      channel: "facebook",
      external_customer_id: "fb-user-123",
      last_message_at: 1.day.ago
    )
    pending_order = conversation.create_pending_order!(status: :collecting_quantity)

    assert_no_difference -> { Conversation.count } do
      assert_no_difference -> { PendingOrder.count } do
        assert_difference -> { Message.count }, 1 do
          post conversation_messages_url, params: {
            conversation_message: {
              channel: "facebook",
              external_customer_id: "fb-user-123",
              content: "I want Fresh Musk"
            }
          }, as: :json
        end
      end
    end

    assert_response :created
    response_body = JSON.parse(response.body)

    assert_equal conversation.id, response_body.dig("conversation", "id")
    assert_equal pending_order.id, response_body.dig("pending_order", "id")
    assert_equal "collecting_quantity", response_body.dig("pending_order", "status")
    assert_equal "I want Fresh Musk", conversation.messages.order(:created_at).last.content
    assert conversation.reload.last_message_at > 1.minute.ago
  end

  test "create returns validation errors for missing content" do
    assert_no_difference -> { Message.count } do
      post conversation_messages_url, params: {
        conversation_message: {
          channel: "facebook",
          external_customer_id: "fb-user-123",
          content: nil
        }
      }, as: :json
    end

    assert_response :unprocessable_entity

    response_body = JSON.parse(response.body)
    assert_equal ["Content can't be blank"], response_body.dig("errors", "content")
  end
end
