require "digest"

class MessagingSafeIdentifier
  def self.call(value)
    return if value.blank?

    Digest::SHA256.hexdigest(value.to_s).first(12)
  end
end
