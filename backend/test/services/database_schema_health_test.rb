require "test_helper"

class DatabaseSchemaHealthTest < ActiveSupport::TestCase
  FakeMigrationContext = Struct.new(:needs_migration?)

  test "reports the test database schema as current" do
    result = DatabaseSchemaHealth.new.call

    assert_equal true, result[:current]
    assert_equal true, result[:migrations_current]
    assert_equal true, result[:contract_current]
    assert_empty result[:missing]
  end

  test "reports pending migrations even when the schema contract is present" do
    result = DatabaseSchemaHealth.new(
      connection: ApplicationRecord.connection,
      migration_context: FakeMigrationContext.new(true)
    ).call

    assert_equal false, result[:current]
    assert_equal false, result[:migrations_current]
    assert_equal true, result[:contract_current]
  end

  test "reports a migration marked complete when a required column is missing" do
    connection = Object.new
    connection.define_singleton_method(:data_source_exists?) { |_table| true }
    connection.define_singleton_method(:column_exists?) do |table, column|
      !(table == "auth_sessions" && column == "revoked_at")
    end

    result = DatabaseSchemaHealth.new(
      connection: connection,
      migration_context: FakeMigrationContext.new(false)
    ).call

    assert_equal false, result[:current]
    assert_equal true, result[:migrations_current]
    assert_equal false, result[:contract_current]
    assert_equal [ "column:auth_sessions.revoked_at" ], result[:missing]
  end
end
