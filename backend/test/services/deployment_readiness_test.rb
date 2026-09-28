require "test_helper"

class DeploymentReadinessTest < ActiveSupport::TestCase
  test "reports database and queue readiness without exposing connection details" do
    result = DeploymentReadiness.new.call

    assert_equal true, result[:ready]
    assert_equal({ database: true, queue: true }, result[:checks])
    assert_equal %i[ready checks], result.keys
  end
end
