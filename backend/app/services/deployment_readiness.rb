class DeploymentReadiness
  def call
    checks = {
      database: available? { ApplicationRecord.connection.select_value("SELECT 1") },
      queue: available? { SolidQueue::Job.table_exists? }
    }
    { ready: checks.values.all?, checks: checks }
  end

  private

  def available?
    yield
    true
  rescue StandardError
    false
  end
end
