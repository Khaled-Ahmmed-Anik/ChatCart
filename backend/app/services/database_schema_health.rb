class DatabaseSchemaHealth
  REQUIRED_SCHEMA = {
    "auth_sessions" => %w[revoked_at revocation_reason],
    "businesses" => %w[status],
    "conversations" => %w[business_id conversation_state],
    "pending_orders" => %w[change_history product_variant_id],
    "pending_order_items" => %w[pending_order_id product_id product_variant_id quantity],
    "products" => %w[business_id product_attributes product_type],
    "users" => %w[active password_digest]
  }.freeze

  def initialize(
    connection: ApplicationRecord.connection,
    migration_context: ApplicationRecord.connection_pool.migration_context
  )
    @connection = connection
    @migration_context = migration_context
  end

  def call
    missing = missing_schema_items
    migrations_current = !migration_context.needs_migration?

    {
      current: migrations_current && missing.empty?,
      migrations_current: migrations_current,
      contract_current: missing.empty?,
      missing: missing
    }
  end

  private

  attr_reader :connection, :migration_context

  def missing_schema_items
    REQUIRED_SCHEMA.flat_map do |table, columns|
      next [ "table:#{table}" ] unless connection.data_source_exists?(table)

      columns.reject { |column| connection.column_exists?(table, column) }
        .map { |column| "column:#{table}.#{column}" }
    end
  end
end
