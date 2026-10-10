class MetaWebhookSignatureVerifier
  def self.valid?(payload:, signature:, app_secret:)
    signature_match = signature&.match(/\Asha256=([0-9a-f]{64})\z/i)
    return false if app_secret.blank? || signature_match.nil?

    expected = OpenSSL::HMAC.hexdigest("SHA256", app_secret, payload)
    ActiveSupport::SecurityUtils.secure_compare(expected, signature_match[1].downcase)
  end
end
