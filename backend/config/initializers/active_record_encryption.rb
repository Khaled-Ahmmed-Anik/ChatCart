require "digest"

application_secret = Rails.application.secret_key_base

Rails.application.config.active_record.encryption.primary_key =
  ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"].presence || Digest::SHA256.hexdigest("#{application_secret}:primary")
Rails.application.config.active_record.encryption.deterministic_key =
  ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"].presence || Digest::SHA256.hexdigest("#{application_secret}:deterministic")
Rails.application.config.active_record.encryption.key_derivation_salt =
  ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"].presence || Digest::SHA256.hexdigest("#{application_secret}:salt")
