require "minitest/autorun"
require_relative "../lib/oracle_migration_preflight"

class OracleMigrationPreflightTest < Minitest::Test
  def valid_environment
    OracleMigrationPreflight::REQUIRED.to_h { |key| [ key, "existing-production-value" ] }.merge(
      "APP_DOMAIN" => "api.chatcart.test", "APP_HOST" => "api.chatcart.test",
      "DASHBOARD_ORIGIN" => "https://chatcart-dashboard.pages.dev",
      "DATABASE_URL" => "postgresql://owner:private-password@db.neon.test/neondb?sslmode=require",
      "RAILS_ENV" => "production", "FORCE_SSL" => "true"
    )
  end

  def test_accepts_complete_configuration
    assert_empty OracleMigrationPreflight.errors(valid_environment)
  end

  def test_rejects_templates_without_exposing_values
    env = valid_environment.merge("SECRET_KEY_BASE" => "replace-this-sensitive-value")
    errors = OracleMigrationPreflight.errors(env).join
    assert_includes errors, "SECRET_KEY_BASE"
    refute_includes errors, "replace-this-sensitive-value"
  end

  def test_rejects_insecure_database_and_invalid_origins
    %w[http://dashboard.test https://dashboard.test/path https://user:password@dashboard.test].each do |origin|
      assert OracleMigrationPreflight.errors(valid_environment.merge("DASHBOARD_ORIGIN" => origin)).any?
    end
    assert OracleMigrationPreflight.errors(valid_environment.merge("DATABASE_URL" => "postgres://owner:secret@db.test/app")).any?
  end

  def test_rejects_mismatched_host_and_disabled_ssl
    assert OracleMigrationPreflight.errors(valid_environment.merge("APP_HOST" => "other.test")).any?
    assert OracleMigrationPreflight.errors(valid_environment.merge("FORCE_SSL" => "false")).any?
  end

  def test_reports_missing_configuration_without_secrets
    errors = OracleMigrationPreflight.errors({})
    OracleMigrationPreflight::REQUIRED.each do |key|
      assert errors.any? { |error| error.include?(key) }
    end
  end

  def test_rejects_example_and_malformed_database_urls
    [ "postgresql://user:replace-password@host/database?sslmode=require", "not a URL", "https://db.test/app?sslmode=require" ].each do |url|
      assert OracleMigrationPreflight.errors(valid_environment.merge("DATABASE_URL" => url)).any?
    end
  end
end
