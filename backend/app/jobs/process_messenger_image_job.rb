class ProcessMessengerImageJob < ApplicationJob
  queue_as :messenger_inbound
  retry_on ActiveRecord::Deadlocked, wait: :polynomially_longer, attempts: 5

  def perform(event)
    return unless event.event_type == "customer_image"

    if event.messenger_delivery
      SendMessengerReplyJob.perform_later(event.messenger_delivery) if event.messenger_delivery.status.in?(%w[pending retrying])
      return
    end
    return unless claim_event(event)

    claim_time = event.updated_at
    urls = customer_image_urls(event)
    existing_conversation = event.business.conversations.find_by(channel: "facebook", external_customer_id: event.sender_id)
    if event.business.active? && !existing_conversation&.handed_over?
      product = CustomerPhotoRecognizer.new(business: event.business, urls: urls).recognize
    end
    delivery = record_result(event, claim_time, urls, product)
    SendMessengerReplyJob.perform_later(delivery) if delivery
  rescue StandardError => error
    mark_failed(event, claim_time, error) if event&.persisted? && claim_time
    raise
  end

  private

  def claim_event(event)
    event.with_lock do
      next false if event.status.in?(%w[processed ignored]) ||
        (event.status == "processing" && event.updated_at > Constants::PhotoRecognition::PROCESSING_LEASE.ago)

      event.update!(status: "processing", last_error: nil)
      true
    end
  end

  def customer_image_urls(event)
    Array(event.payload.dig("message", "attachments")).filter_map do |attachment|
      attachment.dig("payload", "url") if attachment["type"] == "image"
    end
  end

  def record_result(event, claim_time, urls, product)
    event.with_lock do
      next unless event.status == "processing" && event.updated_at == claim_time

      unless event.business.reload.active?
        event.update!(status: "ignored", processed_at: Time.current)
        next
      end
      delivery = nil
      conversation = event.business.conversations.find_or_create_by!(channel: "facebook", external_customer_id: event.sender_id)
      conversation.with_lock do
        newer_customer_turn = conversation.messages.customer.where("created_at > ?", event.created_at).exists?
        caption = event.payload.dig("message", "text").to_s
        conversation.messages.create!(sender_type: :customer, content: caption.presence || I18n.t("photo_recognition.photo"),
          created_at: event.created_at,
          metadata: { "photo_count" => urls.size, "messenger_message_id" => event.external_event_id })
        conversation.update!(last_message_at: [ conversation.last_message_at, event.created_at ].compact.max)
        unless conversation.handed_over? || newer_customer_turn
          delivery = create_delivery(event, conversation, product)
        end
      end
      event.update!(status: "processed", processed_at: Time.current, last_error: nil)
      delivery
    end
  end

  def create_delivery(event, conversation, product)
    product = event.business.products.where(active: true).find_by(id: product.id) if product
    key = product ? "match" : "fallback"
    reply = conversation.messages.create!(sender_type: :bot,
      content: I18n.t("photo_recognition.#{key}", product: product&.name, locale: reply_locale(conversation)),
      metadata: { "photo_recognition" => true, "suggested_product_id" => product&.id })
    MessengerDelivery.create!(messenger_webhook_event: event, message: reply, recipient_id: event.sender_id)
  end

  def mark_failed(event, claim_time, error)
    event.with_lock do
      event.update!(status: "failed", last_error: error.class.name) if event.status == "processing" && event.updated_at == claim_time
    end
  end

  def reply_locale(conversation)
    language = conversation.conversation_state.to_h["preferred_language"].presence || conversation.business.default_language
    { "bengali" => :bn, "bn" => :bn, "banglish" => :banglish }.fetch(language, :en)
  end
end
