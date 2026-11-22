require "uri"

# Configuration-only checks: no Rails boot, database writes or secret output.
class OracleMigrationPreflight
  REQUIRED = %w[
    SECRET_KEY_BASE RAILS_MASTER_KEY ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY
    ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT
    MESSENGER_VERIFY_TOKEN MESSENGER_APP_SECRET GEMINI_API_KEY GEMINI_MODEL
  ].freeze

  def self.errors(env)
    errors = REQUIRED.filter_map do |key|
      "#{key} must contain the existing production value" if placeholder?(env[key])
    end
    %w[APP_DOMAIN APP_HOST].each do |key|
      value = env[key].to_s
      errors << "#{key} must be a real hostname without scheme or path" unless
        value.match?(/\A[a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\z/i) && value.include?(".") && !placeholder?(value)
    end
    errors << "APP_HOST must equal APP_DOMAIN" unless env["APP_HOST"] == env["APP_DOMAIN"]
    errors << "DASHBOARD_ORIGIN must be an HTTPS origin without a path" unless https_origin?(env["DASHBOARD_ORIGIN"])
    errors << "DATABASE_URL must use PostgreSQL with sslmode=require or verify-full" unless database_url?(env["DATABASE_URL"])
    errors << "RAILS_ENV must be production" unless env["RAILS_ENV"] == "production"
    errors << "FORCE_SSL must be true" unless env["FORCE_SSL"] == "true"
    errors
  end

  def self.placeholder?(value)
    value.to_s.strip.empty? || value.match?(/replace|generate|example\.(com|org)|localhost/i)
  end

  def self.https_origin?(value)
    uri = URI.parse(value.to_s)
    uri.scheme == "https" && uri.host && !uri.userinfo && !uri.query && !uri.fragment &&
      [ "", "/" ].include?(uri.path) && !placeholder?(value)
  rescue URI::InvalidURIError
    false
  end

  def self.database_url?(value)
    uri = URI.parse(value.to_s)
    %w[postgres postgresql].include?(uri.scheme) && uri.host && uri.user && uri.password &&
      uri.path.to_s.length > 1 && !placeholder?(value) &&
      URI.decode_www_form(uri.query.to_s).any? { |key, mode| key == "sslmode" && %w[require verify-full].include?(mode) }
  rescue URI::InvalidURIError, ArgumentError
    false
  end
end
