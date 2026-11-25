require "test_helper"

class HealthTest < ActionDispatch::IntegrationTest
  test "Rails responds to its health route" do
    get rails_health_check_path

    assert_response :ok
  end
end
