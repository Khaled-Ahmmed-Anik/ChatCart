namespace :deployment do
  desc "Fail deployment when primary migrations or critical schema objects are missing"
  task verify_schema: :environment do
    result = DatabaseSchemaHealth.new.call
    next puts("Production database schema is current.") if result[:current]

    warn "Production database schema verification failed."
    warn "- Pending primary migrations exist." unless result[:migrations_current]
    result[:missing].each { |item| warn "- Missing #{item}" }
    abort
  end

  desc "Validate production environment settings without printing secrets"
  task preflight: :environment do
    required = %w[
      DATABASE_URL SECRET_KEY_BASE RAILS_MASTER_KEY
      ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY
      ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT APP_HOST DASHBOARD_ORIGIN
      PLATFORM_ADMIN_EMAIL PLATFORM_ADMIN_PASSWORD CHATCART_OWNER_EMAIL CHATCART_OWNER_PASSWORD
      MESSENGER_VERIFY_TOKEN MESSENGER_PAGE_ACCESS_TOKEN MESSENGER_APP_SECRET GEMINI_API_KEY
    ]
    placeholder = /replace|generate|your-|example\.com|password@host/i
    errors = required.filter_map do |key|
      value = ENV[key].to_s
      "#{key} is missing" if value.blank?
    end
    errors.concat(required.filter_map do |key|
      value = ENV[key].to_s
      "#{key} still contains a placeholder" if value.present? && value.match?(placeholder)
    end)

    errors << "DASHBOARD_ORIGIN must be an https:// origin without a trailing slash" unless
      ENV["DASHBOARD_ORIGIN"].to_s.match?(/\Ahttps:\/\/[^\/]+\z/)
    errors << "APP_HOST must be a hostname without http://, https://, or a path" unless
      ENV["APP_HOST"].to_s.match?(/\A[^:\/\s]+\z/)
    errors << "DATABASE_URL should require TLS (sslmode=require)" unless
      ENV["DATABASE_URL"].to_s.include?("sslmode=require")

    whatsapp_keys = %w[WHATSAPP_VERIFY_TOKEN WHATSAPP_ACCESS_TOKEN WHATSAPP_APP_SECRET WHATSAPP_PHONE_NUMBER_ID]
    configured_whatsapp = whatsapp_keys.count { |key| ENV[key].present? }
    errors << "Configure every WhatsApp variable or leave all four blank" if configured_whatsapp.between?(1, 3)

    if errors.any?
      warn "Deployment preflight failed:"
      errors.each { |error| warn "- #{error}" }
      abort
    end

    puts "Deployment preflight passed. Required settings are present and structurally valid."
  end
end
