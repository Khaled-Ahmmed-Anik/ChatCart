class SubmitDeliveryJob < ApplicationJob
  class TemporaryDeliveryError < StandardError; end

  queue_as :delivery
  retry_on TemporaryDeliveryError, wait: :polynomially_longer, attempts: 5

  def perform(submission)
    return if submission.status == "submitted"

    submission.update!(status: "submitting", attempts: submission.attempts + 1, last_error: nil)
    result = DeliverySubmissionSender.new(submission).deliver
    if result.success
      submission.update!(status: "submitted", response_code: result.status,
        external_reference: result.external_reference, submitted_at: Time.current)
      submission.order.update!(status: "submitted", submitted_at: Time.current)
    elsif result.retryable
      submission.update!(status: "retrying", response_code: result.status, last_error: result.error)
      raise TemporaryDeliveryError, result.error
    else
      submission.update!(status: "failed", response_code: result.status, last_error: result.error)
    end
  end
end
