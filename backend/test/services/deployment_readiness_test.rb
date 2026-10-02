require "test_helper"

class DeploymentReadinessTest < ActiveSupport::TestCase
  test "reports database and queue readiness without exposing connection details" do
    result = DeploymentReadiness.new.call

    assert_equal true, result[:ready]
    assert_equal({ database: true, migrations: true, schema_contract: true, queue: true }, result[:checks])
    assert_equal %i[ready checks], result.keys
  end

  test "reports not ready when a migration record and required schema disagree" do
    schema_health = Object.new
    schema_result = {
      current: false,
      migrations_current: true,
      contract_current: false,
      missing: [ "column:auth_sessions.revoked_at" ]
    }
    schema_health.define_singleton_method(:call) { schema_result }

    result = DeploymentReadiness.new(schema_health: schema_health).call

    assert_equal false, result[:ready]
    assert_equal false, result.dig(:checks, :schema_contract)
    assert_equal [ "column:auth_sessions.revoked_at" ], result[:missing_schema_items]
  end
end
