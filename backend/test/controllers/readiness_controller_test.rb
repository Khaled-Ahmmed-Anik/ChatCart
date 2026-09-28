require "test_helper"

class ReadinessControllerTest < ActionDispatch::IntegrationTest
  test "readiness is public and reports dependency status" do
    get readiness_path

    assert_response :success
    assert_equal true, response.parsed_body["ready"]
    assert_equal({ "database" => true, "queue" => true }, response.parsed_body["checks"])
  end
end
