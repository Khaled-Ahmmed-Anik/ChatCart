class DeploymentReadiness
  def initialize(schema_health: DatabaseSchemaHealth.new)
    @schema_health = schema_health
  end

  def call
    schema = schema_health
    checks = {
      database: available? { ApplicationRecord.connection.select_value("SELECT 1") },
      migrations: schema[:migrations_current],
      schema_contract: schema[:contract_current],
      queue: available? { SolidQueue::Job.table_exists? }
    }
    result = { ready: checks.values.all?, checks: checks }
    result[:missing_schema_items] = schema[:missing] if schema[:missing].any?
    result
  end

  private

  def available?
    yield
    true
  rescue StandardError
    false
  end

  def schema_health
    @schema_health.call
  rescue StandardError
    { current: false, migrations_current: false, contract_current: false, missing: [] }
  end
end
